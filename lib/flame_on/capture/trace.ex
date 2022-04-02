defmodule FlameOn.Capture.Trace do
  alias FlameOn.Capture.Server

  @flags [:call, :return_to, :running, :arity, :timestamp, :set_on_spawn]
  def start_trace(tracer) do
    match_spec = [{:_, [], [{:message, {{:cp, {:caller}}}}]}]
    :erlang.trace_pattern(:on_load, match_spec, [:local])
    :erlang.trace_pattern({:_, :_, :_}, match_spec, [:local])
    :erlang.trace(self(), true, [{:tracer, tracer} | @flags])
  end

  def stop_trace do
    :erlang.trace(self(), false, [:all])
    Server.stop_trace()
  end
end
