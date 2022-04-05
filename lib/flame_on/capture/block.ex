defmodule FlameOn.Capture.Block do
  defstruct id: nil,
            children: [],
            duration: nil,
            function: nil,
            level: nil,
            absolute_start: nil,
            max_child_level: nil
end
