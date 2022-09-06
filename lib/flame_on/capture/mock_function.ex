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

  arg_names = Enum.map(1..254, &:"arg#{&1}")

  for n <- 0..254 do
    args = Enum.take(arg_names, n)

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
