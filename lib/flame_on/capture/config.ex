defmodule FlameOn.Capture.Config do
  alias __MODULE__
  defstruct [:module, :function, :arity, :timeout, :target_node, :reply_to]

  def new(module, function, arity, timeout, target_node, reply_to) do
    %Config{
      module: module,
      function: function,
      arity: arity,
      timeout: timeout,
      target_node: target_node,
      reply_to: reply_to
    }
  end
end
