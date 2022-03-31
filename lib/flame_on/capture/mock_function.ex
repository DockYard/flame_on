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

  def generate(_module, _function, 0) do
    pid = self()

    fn ->
      already_started? = start_if_not_started(pid)
      result = :meck.passthrough([])
      if !already_started?, do: Trace.stop_trace()
      result
    end
  end

  def generate(_module, _function, 1) do
    pid = self()

    fn a ->
      already_started? = start_if_not_started(pid)
      result = :meck.passthrough([a])
      if !already_started?, do: Trace.stop_trace()
      result
    end
  end

  def generate(_module, _function, 2) do
    pid = self()

    fn a, b ->
      already_started? = start_if_not_started(pid)
      result = :meck.passthrough([a, b])
      if !already_started?, do: Trace.stop_trace()
      result
    end
  end

  def generate(_module, _function, 3) do
    pid = self()

    fn a, b, c ->
      already_started? = start_if_not_started(pid)
      result = :meck.passthrough([a, b, c])
      if !already_started?, do: Trace.stop_trace()
      result
    end
  end

  def generate(_module, _function, 4) do
    pid = self()

    fn a, b, c, d ->
      already_started? = start_if_not_started(pid)
      result = :meck.passthrough([a, b, c, d])
      if !already_started?, do: Trace.stop_trace()
      result
    end
  end
end
