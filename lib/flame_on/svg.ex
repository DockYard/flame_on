defmodule FlameOn.SVG do
  use Phoenix.LiveComponent
  alias FlameOn.Parser.Block

  def render(assigns) do
    %Block{} = top_block = Map.fetch!(assigns, :block)

    assigns =
      assigns
      |> assign(:blocks, List.flatten(flatten(top_block)))
      |> assign(:duration_ratio, 1276 / top_block.duration)
      |> assign(:block_height, 25)
      |> assign(:top_block, top_block)

    ~H"""
    <svg width="1276" height={@block_height * top_block.max_child_level} style="background-color: white;">
    <style>
      svg > svg {
        cursor: pointer;
      }

      svg > svg > rect {
        stroke: white;
        rx: 5px;
      }

      svg > svg > text {
        font-size: <%= @block_height / 2 %>px;
        font-family: monospace;
        dominant-baseline: middle;
      }
    </style>
      <%= for block <- @blocks do %>
        <%= render_flame_on_block(%{block: block, block_height: @block_height, duration_ratio: @duration_ratio, top_block: @top_block, parent: @parent, socket: @socket}) %>
      <% end %>
    </svg>
    """
  end

  defp render_flame_on_block(%{block: %Block{function: nil}}), do: ""

  defp render_flame_on_block(assigns) do
    color = color_for_function(assigns.block.function)

    ~H"""
    <svg width={Enum.max([trunc(@block.duration * @duration_ratio), 1])} height={@block_height} x={(@block.absolute_start - @top_block.absolute_start) * @duration_ratio} y={(@block.level - @top_block.level) * @block_height} phx-click="view_block" phx-target={@parent} phx-value-id={@block.id}>
      <rect width="100%" height="100%" style={"fill: #{color};"}></rect>
      <text x={@block_height/4} y={@block_height * 0.5}><%=@block.function %></text>
      <title><%= @block.duration %>&micro;s (<%= trunc((@block.duration * 100) / @top_block.duration) %>%) <%=@block.function %></title>
    </svg>
    """
  end

  defp flatten(%Block{children: children} = block) do
    [block | Enum.map(children, &flatten/1)]
  end

  defp color_for_function("Elixir." <> rest), do: color_for_function(rest)

  defp color_for_function(function) do
    module = function |> String.split(":") |> hd() |> String.split(".") |> hd()
    red = :erlang.phash2(module <> "red", 180) |> Kernel.+(75) |> Integer.to_string(16)
    green = :erlang.phash2(module <> "green", 180) |> Kernel.+(75) |> Integer.to_string(16)
    blue = :erlang.phash2(module <> "blue", 180) |> Kernel.+(75) |> Integer.to_string(16)

    "\##{pad(red)}#{pad(green)}#{pad(blue)}"
  end

  defp pad(str) do
    if String.length(str) == 1 do
      "0" <> str
    else
      str
    end
  end
end
