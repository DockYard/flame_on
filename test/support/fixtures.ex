defmodule FlameOn.Fixtures do
  alias FlameOn.Capture.Block

  def simple_block(opts \\ []) do
    %Block{
      id: Keyword.get(opts, :id, Ecto.UUID.generate()),
      children: Keyword.get(opts, :children, []),
      duration: Keyword.get(opts, :duration),
      function: Keyword.get(opts, :function, {:example, :foo, 0}),
      level: Keyword.get(opts, :level),
      absolute_start: Keyword.get(opts, :absolute_start, 0),
      max_child_level: Keyword.get(opts, :max_child_level)
    }
  end

  def simple_trace_events do
    [
      {:call, {:example, :foo, 0}, 1000},
      {:return_to, {:example, :foo, 0}, 2000}
    ]
  end

  def nested_trace_events do
    [
      {:call, {:example, :parent, 0}, 1000},
      {:call, {:example, :child, 0}, 1100},
      {:return_to, {:example, :parent, 0}, 1200},
      {:return_to, {:example, :parent, 0}, 1300}
    ]
  end

  def deeply_nested_trace_events do
    [
      {:call, {:example, :level1, 0}, 1000},
      {:call, {:example, :level2, 0}, 1100},
      {:call, {:example, :level3, 0}, 1200},
      {:return_to, {:example, :level2, 0}, 1300},
      {:return_to, {:example, :level1, 0}, 1400},
      {:return_to, {:example, :level1, 0}, 1500}
    ]
  end

  def recursive_trace_events do
    [
      {:call, {:example, :recursive, 1}, 1000},
      {:call, {:example, :recursive, 1}, 1100},
      {:call, {:example, :recursive, 1}, 1200},
      {:return_to, {:example, :recursive, 1}, 1300},
      {:return_to, {:example, :recursive, 1}, 1400},
      {:return_to, {:example, :recursive, 1}, 1500}
    ]
  end

  def sleep_trace_events do
    [
      {:call, {:example, :foo, 0}, 1000},
      {:call, :sleep, 1100},
      {:return_to, :sleep, 1200},
      {:return_to, {:example, :foo, 0}, 1300}
    ]
  end

  def build_stack_from_trace_events(events) do
    Enum.reduce(events, [], fn
      {:call, function, timestamp}, stack ->
        FlameOn.Capture.Server.Stack.handle_trace_call(stack, function, timestamp)

      {:return_to, function, timestamp}, stack ->
        FlameOn.Capture.Server.Stack.handle_trace_return_to(stack, function, timestamp)
    end)
  end
end
