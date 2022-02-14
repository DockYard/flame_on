defmodule FlameOn.Parser do
  def parse_bggg(bggg) do
    bggg
    |> String.split("\n", trim: true)
    |> Enum.map(&line_to_entry/1)
    |> to_block(0, 0)
  end

  defmodule Entry do
    defstruct line: nil, duration: nil, stack: nil
  end

  defp line_to_entry(line) do
    [duration | reverse_line] = line |> String.split(" ") |> Enum.reverse()

    ["<" <> _pid, line] =
      reverse_line |> Enum.reverse() |> Enum.join() |> String.split(">", parts: 2)

    stack = String.split(line, ";", trim: true)
    %Entry{line: line, duration: String.to_integer(duration), stack: stack}
  end

  defmodule Block do
    defstruct id: nil,
              children: nil,
              duration: nil,
              function: nil,
              level: nil,
              absolute_start: nil,
              max_child_level: nil
  end

  defp to_block([], _, _) do
    nil
  end

  defp to_block(entries, level, absolute_duration) do
    block = %Block{
      id: Ecto.UUID.generate(),
      level: level,
      duration: 0,
      absolute_start: absolute_duration,
      children: []
    }

    {block, _, lists_of_lists_of_child_entries} =
      Enum.reduce(
        entries,
        {block, nil, [[]]},
        fn %Entry{} = entry, {%Block{} = block, current_fn, current_child_entries} ->
          [current_block_fn | tail] = entry.stack

          if block.function != nil and current_block_fn != block.function,
            do: raise("different top level functions passed to to_blocks")

          block = %Block{
            block
            | function: current_block_fn,
              duration: block.duration + entry.duration
          }

          case tail do
            [] ->
              {block, nil, [pop_stack(entry) | current_child_entries]}

            [^current_fn | _tail] ->
              {block, current_fn, add_to_head_head(current_child_entries, pop_stack(entry))}

            [new_current_fn | _tail] ->
              {block, new_current_fn,
               add_to_head_head([[] | current_child_entries], pop_stack(entry))}
          end
        end
      )

    {children, _} =
      lists_of_lists_of_child_entries
      |> Enum.reverse()
      |> Enum.reduce({[], absolute_duration}, fn
        [], acc ->
          acc

        %Entry{} = entry, {children, current_absolute_duration} ->
          block = %Block{
            id: Ecto.UUID.generate(),
            duration: entry.duration,
            absolute_start: current_absolute_duration,
            level: level + 1,
            max_child_level: 0,
            children: []
          }

          {[block | children], current_absolute_duration + entry.duration}

        list_of_child_entries, {children, current_absolute_duration}
        when is_list(list_of_child_entries) ->
          block =
            list_of_child_entries
            |> Enum.reject(&(&1 == []))
            |> Enum.reverse()
            |> to_block(level + 1, current_absolute_duration)

          {[block | children], current_absolute_duration + block.duration}
      end)

    max_child_level = children |> Enum.map(& &1.max_child_level) |> Enum.max()
    %Block{block | children: Enum.reverse(children), max_child_level: max_child_level + 1}
  end

  defp add_to_head_head([hd | tl], entry) do
    [[entry | hd] | tl]
  end

  defp pop_stack(%Entry{stack: [_ | tl]} = entry) do
    %Entry{entry | stack: tl}
  end
end
