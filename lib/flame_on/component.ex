defmodule FlameOn.Component do
  use Phoenix.LiveComponent

  import FlameOn.ErrorHelpers

  use PhoenixHTMLHelpers

  alias FlameOn.Capture.Block
  alias FlameOn.Capture.Config
  alias FlameOn.Component.CaptureSchema

  def update(%{flame_on_update: root_block}, socket) do
    socket =
      socket
      |> assign(:capturing?, false)
      |> assign(:capture_timed_out?, false)
      |> assign(:root_block, root_block)
      |> assign(:viewing_block, root_block)
      |> assign(:html_render, nil)
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

  def update(%{html_render: html}, socket) do
    {:ok, assign(socket, :html_render, html)}
  end

  def update(assigns, socket) do
    target_node = Map.get(assigns, :node, Node.self())
    capture_changeset = Map.put(CaptureSchema.changeset(target_node), :action, :validate)

    socket =
      if !Map.has_key?(socket.assigns, :id) do
        socket
        |> assign(:capturing?, false)
        |> assign(:root_block, nil)
        |> assign(:capture_changeset, capture_changeset)
        |> assign(:viewing_block, nil)
        |> assign(:view_block_path, [])
        |> assign(:capture_timed_out?, false)
        |> assign(:id, assigns.id)
        |> assign(:target_node, target_node)
        |> assign(:html_render, nil)
      else
        socket
      end

    {:ok, socket}
  end

  def handle_event("capture_schema", %{"capture_schema" => attrs}, socket) do
    changeset = CaptureSchema.changeset(socket.assigns.target_node, attrs)

    {socket, changeset} =
      if changeset.valid? do
        config =
          Config.new(
            Ecto.Changeset.fetch_field!(changeset, :module)
            |> CaptureSchema.maybe_prepend_elixir()
            |> String.to_existing_atom(),
            Ecto.Changeset.fetch_field!(changeset, :function) |> String.to_existing_atom(),
            Ecto.Changeset.fetch_field!(changeset, :arity),
            Ecto.Changeset.fetch_field!(changeset, :timeout),
            socket.assigns.target_node,
            {:live_component, self(), socket.assigns.id}
          )

        FlameOn.Capture.capture(config)

        socket =
          socket
          |> assign(:capturing?, true)
          |> assign(:capture_timed_out?, false)

        {socket, changeset}
      else
        {:error, changeset} = Ecto.Changeset.apply_action(changeset, :insert)
        {socket, changeset}
      end

    socket = assign(socket, :capture_changeset, changeset)
    {:noreply, socket}
  end

  def handle_event("validate", %{"capture_schema" => attrs}, socket) do
    changeset =
      socket.assigns.target_node
      |> CaptureSchema.changeset(attrs)
      |> Map.put(:action, :validate)

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
