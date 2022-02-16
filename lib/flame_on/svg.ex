defmodule FlameOn.SVG do
  use Phoenix.LiveComponent
  alias FlameOn.Parser.Block

  def render(assigns) do
    %Block{} = block = Map.fetch!(assigns, :block)
    block_height = block_height(block)

    assigns =
      assigns
      |> assign(:blocks, List.flatten(flatten(block)))
      |> assign(:block_height, block_height)
      |> assign(:viewbox, viewbox_for_block(block))

    ~H"""
    <svg width="100%" height="100%" viewbox={@viewbox}>
      <%= for block <- @blocks do %>
        <%= render_flame_on_block(%{block: block, block_height: @block_height, total_duration: @block.duration, parent: @parent, socket: @socket}) %>
      <% end %>
    </svg>
    """
  end

  def block_height(%Block{duration: duration}), do: trunc(duration / 100_000 * 25)

  defp render_flame_on_block(%{block: %Block{function: nil}}), do: ""

  defp render_flame_on_block(assigns) do
    color = color_for_function(assigns.block.function)

    ~H"""
    <a href="#" phx-click="view_block" phx-target={@parent} phx-value-id={@block.id}><%= @block.function %>
      <svg width={@block.duration / 100} height={@block_height * 0.95} x={@block.absolute_start / 100} y={@block.level * @block_height} >
        <rect width="100%" height="100%" style={"fill: #{color}; stroke: white;"}></rect>
        <text x={@block_height/4} y={@block_height * 0.5} font-size={@block_height * 0.5} font-family="monospace" dominant-baseline="middle"><%=@block.function %></text>
        <title><%= @block.duration %>&micro;s (<%= trunc((@block.duration * 100) / @total_duration) %>%) <%=@block.function %></title>
      </svg>
    </a>
    """
  end

  defp flatten(%Block{children: children} = block) do
    [block | Enum.map(children, &flatten/1)]
  end

  defp color_for_function("Elixir." <> rest), do: color_for_function(rest)

  defp color_for_function(function) do
    module = function |> String.split(":") |> hd() |> String.split(".") |> hd()
    red = :erlang.phash2(module <> "red", 205) |> Kernel.+(50) |> Integer.to_string(16)
    green = :erlang.phash2(module <> "green", 205) |> Kernel.+(50) |> Integer.to_string(16)
    blue = :erlang.phash2(module <> "blue", 205) |> Kernel.+(50) |> Integer.to_string(16)

    "\##{pad(red)}#{pad(green)}#{pad(blue)}"
  end

  defp pad(str) do
    if String.length(str) == 1 do
      "0" <> str
    else
      str
    end
  end

  defp viewbox_for_block(%Block{duration: duration, max_child_level: max_child_level} = block) do
    block_height = FlameOn.SVG.block_height(block)

    "#{trunc(block.absolute_start / 100)} #{block_height * block.level} #{trunc(duration / 100)} #{block_height * (max_child_level + 1)}"
  end
end
