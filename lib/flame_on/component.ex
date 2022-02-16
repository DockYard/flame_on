defmodule FlameOn.Component do
  use Phoenix.LiveComponent
  use Phoenix.HTML
  import Ecto.Changeset

  import FlameOn.ErrorHelpers

  alias FlameOn.Parser.Block

  defmodule CaptureSchema do
    use Ecto.Schema
    import Ecto.Changeset

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
    end
  end

  def update(%{flame_on_results: root_block}, socket) do
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
      else
        socket
      end

    {:ok, socket}
  end

  def handle_event("capture_schema", %{"capture_schema" => attrs}, socket) do
    changeset = CaptureSchema.changeset(attrs)

    socket =
      if changeset.valid? do
        values = changeset_to_atom_values(changeset)

        FlameOn.Capture.capture(
          values.module,
          values.function,
          values.arity,
          self(),
          socket.assigns.id,
          values.timeout
        )

        assign(socket, :capturing?, true)
      else
        socket
      end

    socket = assign(socket, :capture_changeset, changeset)
    {:noreply, socket}
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

  defp changeset_to_atom_values(%Ecto.Changeset{} = changeset) do
    module = Ecto.Changeset.fetch_field!(changeset, :module)
    function = Ecto.Changeset.fetch_field!(changeset, :function)
    arity = Ecto.Changeset.fetch_field!(changeset, :arity)
    timeout = Ecto.Changeset.fetch_field!(changeset, :timeout)

    %{
      module: String.to_existing_atom(module),
      function: String.to_existing_atom(function),
      arity: arity,
      timeout: timeout
    }
  end
end
