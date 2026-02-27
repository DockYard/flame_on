defmodule FlameOn.Capture.TraceTest do
  use ExUnit.Case, async: false

  alias FlameOn.Capture.Trace

  describe "start_trace/1" do
    test "enables tracing on current process" do
      tracer = spawn(fn -> :timer.sleep(1000) end)

      result = Trace.start_trace(tracer)

      assert result == 1

      info = Process.info(self(), :trace)
      assert {:trace, _} = info
    end

    test "sets up trace patterns" do
      tracer = spawn(fn -> :timer.sleep(1000) end)

      Trace.start_trace(tracer)

      info = :erlang.trace_info({:erlang, :spawn, 2}, :traced)
      assert info == {:traced, :local}
    end

    test "returns number of traced processes" do
      tracer = spawn(fn -> :timer.sleep(1000) end)

      result = Trace.start_trace(tracer)

      assert is_integer(result)
      assert result >= 1
    end
  end

  describe "stop_trace/0" do
    test "disables tracing on current process" do
      tracer = spawn(fn -> :timer.sleep(1000) end)
      Trace.start_trace(tracer)

      result = Trace.stop_trace()

      assert result == :ok
    end

    test "removes all trace flags" do
      tracer = spawn(fn -> :timer.sleep(1000) end)
      Trace.start_trace(tracer)

      Trace.stop_trace()

      info = Process.info(self(), :trace)
      assert info == {:trace, 0}
    end
  end
end
