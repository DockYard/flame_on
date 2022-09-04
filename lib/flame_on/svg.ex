defmodule FlameOn.SVG do
  use Phoenix.LiveComponent

  import FlameOn.Format

  alias FlameOn.Capture.Block

  def mount(socket) do
    socket = assign(socket, :block_height, 25)
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div style={"overflow: hidden; position: relative; width: 1276px; height: #{@block_height * @root_block.max_child_level}px"}>
      <svg style={"background-color: white; position: absolute; #{svg_zoom_style(@root_block, @viewing_block, @block_height)}"}>
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

        <%= for block <- flattened_blocks(@root_block) do %>
          <%= render_flame_on_block(%{block: block, block_height: @block_height, top_block: @root_block, parent: @parent}) %>
        <% end %>
      </svg>
    </div>
    """
  end

  defp svg_zoom_style(root_block, viewing_block, block_height) do
    # The x-scaling factor is >= 1.0; it represents how many times shorter the viewing_block
    # is compared to the root_block
    x_scale = root_block.duration / viewing_block.duration

    # Scale the SVG to the width of the viewing_block
    width = pct(x_scale)

    # The height is always 100%
    height = pct(1)

    # Move the left edge of the SVG outside the canvas based on its start time and the scaling factor,
    # then turn that into a percentage based on the full capture duration
    left = pct(-1 * x_scale * (viewing_block.absolute_start - root_block.absolute_start), root_block.duration)

    # Move the top edge of the SVG outside the canvas based on the row height and number of levels
    top = "#{-block_height * (viewing_block.level - 1)}px"

    "width: #{width}; height: #{height}; top: #{top}; left: #{left}"
  end


  defp flattened_blocks(top_block) do
    List.flatten(flatten(top_block))
  end

  defp flatten(%Block{children: children} = block) do
    [block | Enum.map(children, &flatten/1)]
  end

  defp render_flame_on_block(%{block: %Block{function: nil}}), do: ""

  defp render_flame_on_block(assigns) do
    color = color_for_function(assigns.block.function)

    ~H"""
    <svg width={pct(@block.duration, @top_block.duration)} height={@block_height} x={pct(@block.absolute_start - @top_block.absolute_start, @top_block.duration)} y={(@block.level - @top_block.level) * @block_height} phx-click="view_block" phx-target={@parent} phx-value-id={@block.id}>
      <rect width="100%" height="100%" style={"fill: #{color};"}></rect>
      <text x={@block_height/4} y={@block_height * 0.5}><%= mfa_to_string(@block.function) %></text>
      <title><%= format_integer(@block.duration) %>&micro;s (<%= trunc((@block.duration * 100) / @top_block.duration) %>%) <%= mfa_to_string(@block.function) %></title>
    </svg>
    """
  end

  defp color_for_function({module, _, _}) do
    case "#{module}" do
      "Elixir." <> rest -> rest
      other -> other
    end
    |> String.split(".")
    |> hd()
    |> color_for_module()
  end

  defp color_for_function(:sleep) do
    color_for_module("sleep")
  end

  defp color_for_module(module) do
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

  defp format_integer(integer) do
    integer
    |> Integer.to_charlist()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  defp pct(numerator, denominator \\ 1) do
    "#{numerator / denominator * 100}%"
  end
end
