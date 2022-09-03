defmodule FlameOn.Capture.MockFunction do
  alias FlameOn.Capture.Trace
  alias FlameOn.Capture.Server

  defp start_if_not_started(pid) do
    already_started? = Server.trace_started?()

    if !already_started? do
      Trace.start_trace(pid)
    end

    already_started?
  end

  for n <- 0..26 do
    args = Enum.take(~w(a b c d e f g h i j k l m n o p q r s t u v w x y z)a, n)

    def generate(_module, _function, unquote(n)) do
      pid = self()

      fn unquote_splicing(Enum.map(args, &Macro.var(&1, __MODULE__))) ->
        already_started? = start_if_not_started(pid)
        result = :meck.passthrough(unquote(Enum.map(args, &Macro.var(&1, __MODULE__))))
        if !already_started?, do: Trace.stop_trace()
        result
      end
    end
  end
end
