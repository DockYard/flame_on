defmodule FlameOn.Capture.Server do
  use GenServer

  alias FlameOn.Capture.Block
  alias FlameOn.Capture.Config
  alias FlameOn.Capture.MockFunction
  alias FlameOn.Capture.Server.State
  alias FlameOn.Capture.Server.Stack

  defmodule State do
    defstruct stack: [], config: nil, trace_started?: false
  end

  def start(%Config{} = config) do
    GenServer.start(__MODULE__, config, name: __MODULE__)
  end

  @doc """
  This function both checks if the trace has already started, and if not, flips
  the boolean to true. The caller is actually starting the trace, but this is the
  singleton to track that it has started for a given capture
  """
  def trace_started? do
    GenServer.call(__MODULE__, :trace_started?)
  end

  def stop_trace do
    GenServer.cast(__MODULE__, :stop_trace)
  end

  def init(%Config{} = config) do
    mock_function(config)
    starter_block = %Block{id: "starter", function: {config.module, config.function, config.arity}, absolute_start: 0}
    Process.send_after(self(), :timeout, config.timeout)
    {:ok, %State{config: config, stack: [starter_block]}}
  end

  def handle_info({:trace_ts, _, :call, mfa, _, timestamp}, %State{stack: stack} = state) do
    stack = Stack.handle_trace_call(stack, mfa, microseconds(timestamp))
    {:noreply, %State{state | stack: stack}}
  end

  def handle_info({:trace_ts, _, :return_to, mfa, timestamp}, %State{stack: stack} = state) do
    stack = Stack.handle_trace_return_to(stack, mfa, microseconds(timestamp))
    {:noreply, %State{state | stack: stack}}
  end

  def handle_info({:trace_ts, _, :out, _mfa, timestamp}, %State{stack: stack} = state) do
    stack = Stack.handle_trace_call(stack, :sleep, microseconds(timestamp))
    {:noreply, %State{state | stack: stack}}
  end

  def handle_info({:trace_ts, _, :in, _mfa, timestamp}, %State{stack: stack} = state) do
    stack = Stack.handle_trace_return_to(stack, :sleep, microseconds(timestamp))
    {:noreply, %State{state | stack: stack}}
  end

  def handle_info(:do_stop_trace, state) do
    state = %State{state | stack: Stack.finalize_stack(state.stack)}
    [root_block] = state.stack
    send_update(state.config, root_block)
    {:stop, :normal, state}
  end

  def handle_info(:timeout, %State{} = state) do
    send_timeout(state.config)

    {:stop, :normal, state}
  end

  def handle_call(:trace_started?, _, %State{trace_started?: started?} = state) do
    {:reply, started?, %State{state | trace_started?: true}}
  end

  def handle_cast(:stop_trace, %State{} = state) do
    Process.send_after(self(), :do_stop_trace, 1000)
    {:noreply, state}
  end

  defp send_update(%Config{reply_to: {:live_component, pid, id}}, update) do
    Phoenix.LiveView.send_update(pid, FlameOn.Component,
      id: id,
      flame_on_update: update
    )
  end

  defp send_timeout(%Config{reply_to: {:live_component, pid, id}}) do
    Phoenix.LiveView.send_update(pid, FlameOn.Component, id: id, flame_on_timed_out: true)
  end

  def mock_function(%Config{} = config) do
    fun = MockFunction.generate(config.module, config.function, config.arity)

    :ok = :meck.new(config.module, [:unstick, :passthrough])
    :ok = :meck.expect(config.module, config.function, fun)
  end

  def microseconds({mega, secs, micro}), do: mega * 1000 * 1000 * 1000 * 1000 + secs * 1000 * 1000 + micro
end
