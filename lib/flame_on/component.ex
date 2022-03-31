defmodule FlameOn.Component do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import Ecto.Changeset
  import FlameOn.ErrorHelpers

  alias FlameOn.Capture.Block
  alias FlameOn.Capture.Config

  defmodule CaptureSchema do
    use Ecto.Schema
    import Ecto.Changeset
    alias Ecto.Changeset

    schema "capture" do
      field :module, :string
      field :function, :string
      field :arity, :integer
      field :timeout, :integer
    end

    @default_attrs %{module: "cowboy_handler", function: "execute", arity: 2, timeout: 15000}

    def changeset(attrs \\ @default_attrs) do
      %__MODULE__{}
      |> cast(attrs, [:module, :function, :arity, :timeout])
      |> validate_required([:module, :function, :arity, :timeout])
      |> validate_module()
      |> validate_function_arity()
    end

    def validate_module(%Changeset{valid?: false} = changeset), do: changeset

    def validate_module(changeset) do
      module_str = get_field(changeset, :module)

      module =
        try do
          String.to_existing_atom(module_str)
        rescue
          ArgumentError -> nil
        end

      if is_nil(module) or (!function_exported?(module, :__info__, 1) and !:erlang.module_loaded(module)) do
        if String.contains?(module_str, ".") and !String.starts_with?(module_str, "Elixir.") do
          add_error(changeset, :module, "Elixir modules must start with \"Elixir.\"")
        else
          add_error(changeset, :module, "Module does not exist")
        end
      else
        changeset
      end
    end

    def validate_function_arity(%Changeset{valid?: false} = changeset), do: changeset

    def validate_function_arity(changeset) do
      module = changeset |> get_field(:module) |> String.to_existing_atom()
      function_str = get_field(changeset, :function)
      arity = get_field(changeset, :arity)

      function =
        try do
          String.to_existing_atom(function_str)
        rescue
          ArgumentError -> nil
        end

      if is_nil(function) or !function_exported?(module, function, arity) do
        add_error(changeset, :function, "No #{function_str}/#{arity} function on #{module}")
      else
        changeset
      end
    end
  end

  def update(%{flame_on_update: root_block}, socket) do
    socket =
      socket
      |> assign(:capturing?, false)
      |> assign(:capture_timed_out?, false)
      |> assign(:root_block, root_block)
      |> assign(:viewing_block, root_block)
      |> assign(:view_block_path, [])

    {:ok, socket}
  end

  def update(%{flame_on_timed_out: true}, socket) do
    socket =
      socket
      |> assign(:capturing?, false)
      |> assign(:capture_timed_out?, true)

    {:ok, socket}
  end

  def update(assigns, socket) do
    socket =
      if !Map.has_key?(socket.assigns, :id) do
        socket
        |> assign(:capturing?, false)
        |> assign(:root_block, nil)
        |> assign(:capture_changeset, CaptureSchema.changeset())
        |> assign(:viewing_block, nil)
        |> assign(:view_block_path, [])
        |> assign(:capture_timed_out?, false)
        |> assign(:id, assigns.id)
        |> assign(:target_node, Map.get(assigns, :node, Node.self()))
      else
        socket
      end

    {:ok, socket}
  end

  def handle_event("capture_schema", %{"capture_schema" => attrs}, socket) do
    changeset = CaptureSchema.changeset(attrs)

    socket =
      if changeset.valid? do
        config =
          Config.new(
            Ecto.Changeset.fetch_field!(changeset, :module) |> String.to_existing_atom(),
            Ecto.Changeset.fetch_field!(changeset, :function) |> String.to_existing_atom(),
            Ecto.Changeset.fetch_field!(changeset, :arity),
            Ecto.Changeset.fetch_field!(changeset, :timeout),
            socket.assigns.target_node,
            {:live_component, self(), socket.assigns.id}
          )

        FlameOn.Capture.capture(config)

        socket
        |> assign(:capturing?, true)
        |> assign(:capture_timed_out?, false)
      else
        socket
      end

    socket = assign(socket, :capture_changeset, changeset)
    {:noreply, socket}
  end

  def handle_event("validate", %{"capture_schema" => attrs}, socket) do
    changeset =
      attrs
      |> CaptureSchema.changeset()
      |> Map.put(:action, :insert)

    {:noreply, assign(socket, :capture_changeset, changeset)}
  end

  def handle_event("view_block", %{"id" => id}, socket) do
    [view_block | view_block_path_r] =
      socket.assigns.root_block
      |> find_block(id)
      |> Enum.reverse()

    socket =
      socket
      |> assign(:viewing_block, view_block)
      |> assign(:view_block_path, Enum.reverse(view_block_path_r))

    {:noreply, socket}
  end

  def find_block(%Block{id: id} = block, id), do: List.wrap(block)
  def find_block(%Block{children: []}, _id), do: false

  def find_block(%Block{children: children} = block, id) do
    case Enum.find_value(children, false, &find_block(&1, id)) do
      false -> false
      tail -> [%Block{block | children: nil} | tail]
    end
  end

  defp target_or_local_node(node) do
    if node == Node.self() do
      "local node"
    else
      "node #{node}"
    end
  end
end
