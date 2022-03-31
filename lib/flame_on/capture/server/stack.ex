defmodule FlameOn.Capture.Server.Stack do
  alias FlameOn.Capture.Block

  def finalize_stack([root_block]) do
    children = Enum.reverse(root_block.children)
    absolute_start = hd(children).absolute_start
    last_child = List.last(children)
    absolute_end = last_child.absolute_start + last_child.duration

    root_block = %Block{
      root_block
      | children: children,
        absolute_start: absolute_start,
        duration: absolute_end - absolute_start
    }

    root_block = populate_levels(root_block, 0)

    [root_block]
  end

  # collapse any nodes left over on the stack down to the root block
  def finalize_stack([%Block{absolute_start: absolute_start}, %Block{function: function} | _] = stack) do
    finalize_stack(handle_trace_return_to(stack, function, absolute_start + 1))
  end

  defp populate_levels(%Block{children: []} = block, parent_level) do
    %Block{block | max_child_level: 0, level: parent_level + 1}
  end

  defp populate_levels(%Block{children: children} = block, parent_level) do
    children = Enum.map(children, &populate_levels(&1, parent_level + 1))

    max_child_level =
      children
      |> Enum.map(& &1.max_child_level)
      |> Enum.max()

    %Block{block | children: children, max_child_level: max_child_level + 1, level: parent_level + 1}
  end

  def handle_trace_call(stack, function, timestamp) do
    [
      %Block{
        id: Ecto.UUID.generate(),
        absolute_start: timestamp,
        function: function,
        level: length(stack)
      }
      | stack
    ]
  end

  def handle_trace_return_to(
        [%Block{} = head_block, %Block{} = parent_block | stack],
        function,
        timestamp
      ) do
    head_block = %Block{
      head_block
      | duration: timestamp - head_block.absolute_start,
        children: Enum.reverse(head_block.children)
    }

    parent_block = %Block{parent_block | children: [head_block | parent_block.children]}
    stack = [parent_block | stack]

    cond do
      # returning to the parent block
      parent_block.function == function -> stack
      # returning out of sleep
      {head_block.function, function} == {:sleep, :sleep} -> stack
      # returning to starter block
      match?([_], stack) -> stack
      # returning to a higher function due to tail recursion stack limiting
      true -> maybe_prune_recursive_call(stack, function, timestamp)
    end
  end

  defp maybe_prune_recursive_call(
         [%Block{function: r_fun, children: [%Block{function: r_fun, children: children}]} = parent_block | stack],
         function,
         timestamp
       ) do
    maybe_prune_recursive_call([%Block{parent_block | children: children} | stack], function, timestamp)
  end

  defp maybe_prune_recursive_call(stack, function, timestamp) do
    handle_trace_return_to(stack, function, timestamp)
  end
end
