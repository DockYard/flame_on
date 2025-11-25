defmodule FlameOn.Capture.ServerTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  alias FlameOn.Capture.Config
  alias FlameOn.Capture.Server

  setup do
    on_exit(fn ->
      if Process.whereis(Server) do
        Process.exit(Process.whereis(Server), :kill)
        Process.sleep(100)
      end

      case ETS.Set.wrap_existing(Server) do
        {:ok, set} -> ETS.Set.delete(set)
        _ -> :ok
      end

      :meck.unload()
    end)

    :ok
  end

  describe "microseconds/1" do
    test "converts erlang timestamp to microseconds" do
      timestamp = {1000, 500_000, 250_000}
      result = Server.microseconds(timestamp)

      assert result == 1_000_500_000_250_000
    end

    test "converts zero timestamp" do
      timestamp = {0, 0, 0}
      result = Server.microseconds(timestamp)

      assert result == 0
    end

    test "converts small timestamp" do
      timestamp = {0, 1, 1000}
      result = Server.microseconds(timestamp)

      assert result == 1_001_000
    end
  end

  describe "trace_started?/0" do
    test "returns false on first call" do
      config = build_config()
      {:ok, _pid} = Server.start(config)

      refute Server.trace_started?()
    end

    test "returns true on subsequent calls" do
      config = build_config()
      {:ok, _pid} = Server.start(config)

      Server.trace_started?()
      assert Server.trace_started?()
      assert Server.trace_started?()
    end

    test "returns true when table not found" do
      assert Server.trace_started?()
    end

    test "sets flag to true after first call" do
      config = build_config()
      {:ok, _pid} = Server.start(config)

      first_result = Server.trace_started?()
      second_result = Server.trace_started?()

      refute first_result
      assert second_result
    end
  end

  describe "init/1" do
    test "creates ETS table" do
      config = build_config()
      {:ok, _pid} = Server.start(config)

      assert {:ok, _set} = ETS.Set.wrap_existing(Server)
    end

    test "sets up starter block in stack" do
      config = build_config(module: FlameOnTest.ExampleModule, function: :foo, arity: 0)
      {:ok, _pid} = Server.start(config)

      state = :sys.get_state(Server)

      assert [starter] = state.stack
      assert starter.function == {FlameOnTest.ExampleModule, :foo, 0}
      assert starter.id == "starter"
      assert starter.absolute_start == 0
    end

    test "mocks the target function with :meck" do
      config = build_config(module: FlameOnTest.ExampleModule)
      {:ok, _pid} = Server.start(config)

      assert :meck.validate(FlameOnTest.ExampleModule)
    end

    test "schedules timeout message" do
      config = build_config(timeout: 100)
      {:ok, pid} = Server.start(config)

      ref = Process.monitor(pid)

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 200
    end
  end

  describe "handle_info trace messages" do
    test "handles :call trace message" do
      config = build_config()
      {:ok, pid} = Server.start(config)

      send(pid, {:trace_ts, self(), :call, {:example, :foo, 0}, :arity, {0, 1000, 0}})
      Process.sleep(10)

      state = :sys.get_state(pid)

      assert length(state.stack) == 2
      [head | _] = state.stack
      assert head.function == {:example, :foo, 0}
    end

    test "handles :return_to trace message" do
      config = build_config()
      {:ok, pid} = Server.start(config)

      send(pid, {:trace_ts, self(), :call, {:example, :child, 0}, :arity, {0, 1000, 0}})
      Process.sleep(10)
      send(pid, {:trace_ts, self(), :return_to, {:example, :root, 0}, {0, 2000, 0}})
      Process.sleep(10)

      state = :sys.get_state(pid)

      assert [starter] = state.stack
      assert [child] = starter.children
      assert child.function == {:example, :child, 0}
      assert child.duration == 1_000_000_000
    end

    test "handles :out trace message for sleep" do
      config = build_config()
      {:ok, pid} = Server.start(config)

      log =
        capture_log(fn ->
          send(pid, {:trace_ts, self(), :out, {:example, :foo, 0}, {0, 1000, 0}})
          Process.sleep(10)
        end)

      state = :sys.get_state(pid)

      assert length(state.stack) == 2
      [head | _] = state.stack
      assert head.function == :sleep
      assert log =~ "flame_on trace: out"
    end

    test "handles :in trace message for sleep" do
      config = build_config()
      {:ok, pid} = Server.start(config)

      send(pid, {:trace_ts, self(), :out, {:example, :foo, 0}, {0, 1000, 0}})
      Process.sleep(10)

      log =
        capture_log(fn ->
          send(pid, {:trace_ts, self(), :in, {:example, :foo, 0}, {0, 2000, 0}})
          Process.sleep(10)
        end)

      state = :sys.get_state(pid)

      assert [starter] = state.stack
      assert [sleep_block] = starter.children
      assert sleep_block.function == :sleep
      assert log =~ "flame_on trace: in"
    end

    test "logs trace messages at debug level" do
      config = build_config()
      {:ok, pid} = Server.start(config)

      log =
        capture_log(fn ->
          send(pid, {:trace_ts, self(), :call, {:example, :foo, 0}, :arity, {0, 1000, 0}})
          Process.sleep(10)
        end)

      assert log =~ "flame_on trace: call"
      assert log =~ "{:example, :foo, 0}"
    end
  end

  describe "handle_info :do_stop_trace" do
    test "finalizes stack and sends update" do
      test_pid = self()
      config = build_config(reply_to: {:live_component, test_pid, "test-id"})
      {:ok, pid} = Server.start(config)

      send(pid, {:trace_ts, self(), :call, {:example, :child, 0}, :arity, {0, 1000, 0}})
      Process.sleep(10)
      send(pid, {:trace_ts, self(), :return_to, {FlameOnTest.ExampleModule, :foo, 0}, {0, 2000, 0}})
      Process.sleep(10)

      ref = Process.monitor(pid)
      send(pid, :do_stop_trace)

      assert_receive {:phoenix, :send_update, {{FlameOn.Component, "test-id"}, %{id: "test-id", flame_on_update: root_block}}}, 500

      assert root_block.function == {FlameOnTest.ExampleModule, :foo, 0}
      assert root_block.level == 1
      assert [child] = root_block.children
      assert child.function == {:example, :child, 0}
      assert child.duration == 1_000_000_000

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
    end

    test "stops the server normally" do
      config = build_config()
      {:ok, pid} = Server.start(config)

      ref = Process.monitor(pid)
      send(pid, :do_stop_trace)

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
    end
  end

  describe "handle_info :timeout" do
    test "sends timeout update and stops server" do
      test_pid = self()
      config = build_config(reply_to: {:live_component, test_pid, "test-id"}, timeout: 50)
      {:ok, pid} = Server.start(config)

      ref = Process.monitor(pid)

      assert_receive {:phoenix, :send_update, {{FlameOn.Component, "test-id"}, %{id: "test-id", flame_on_timed_out: true}}}, 200
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
    end

    test "does not send flame_on_update on timeout" do
      test_pid = self()
      config = build_config(reply_to: {:live_component, test_pid, "test-id"}, timeout: 50)
      {:ok, _pid} = Server.start(config)

      assert_receive {:phoenix, :send_update, {_, %{flame_on_timed_out: true}}}, 200
      refute_receive {:phoenix, :send_update, {_, %{flame_on_update: _}}}
    end
  end

  describe "handle_cast :stop_trace" do
    test "schedules :do_stop_trace message" do
      config = build_config()
      {:ok, pid} = Server.start(config)

      Server.stop_trace()

      state = :sys.get_state(pid)
      assert state.config == config
    end

    test "eventually stops the server" do
      config = build_config()
      {:ok, pid} = Server.start(config)

      ref = Process.monitor(pid)
      Server.stop_trace()

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1200
    end
  end

  describe "mock_function/1" do
    test "creates a :meck mock for the module" do
      config = build_config(module: FlameOnTest.ExampleModule, function: :foo)

      Server.mock_function(config)

      assert :meck.validate(FlameOnTest.ExampleModule)
    end

    test "uses unstick and passthrough options" do
      config = build_config(module: FlameOnTest.ExampleModule)

      Server.mock_function(config)

      assert :meck.validate(FlameOnTest.ExampleModule)
      :meck.unload(FlameOnTest.ExampleModule)
    end
  end

  describe "integration" do
    test "handles complete trace sequence" do
      test_pid = self()
      config = build_config(reply_to: {:live_component, test_pid, "integration-test"})
      {:ok, pid} = Server.start(config)

      send(pid, {:trace_ts, self(), :call, {:example, :parent, 0}, :arity, {0, 1000, 0}})
      Process.sleep(10)
      send(pid, {:trace_ts, self(), :call, {:example, :child1, 0}, :arity, {0, 1100, 0}})
      Process.sleep(10)
      send(pid, {:trace_ts, self(), :return_to, {:example, :parent, 0}, {0, 1200, 0}})
      Process.sleep(10)
      send(pid, {:trace_ts, self(), :call, {:example, :child2, 0}, :arity, {0, 1300, 0}})
      Process.sleep(10)
      send(pid, {:trace_ts, self(), :return_to, {:example, :parent, 0}, {0, 1400, 0}})
      Process.sleep(10)

      send(pid, :do_stop_trace)

      assert_receive {:phoenix, :send_update, {_, %{flame_on_update: root}}}, 500

      assert [parent] = root.children
      assert parent.function == {:example, :parent, 0}
      assert [child1, child2] = parent.children
      assert child1.function == {:example, :child1, 0}
      assert child2.function == {:example, :child2, 0}
      assert child1.duration == 100_000_000
      assert child2.duration == 100_000_000
    end

    test "handles sleep pattern" do
      test_pid = self()
      config = build_config(reply_to: {:live_component, test_pid, "sleep-test"})
      {:ok, pid} = Server.start(config)

      send(pid, {:trace_ts, self(), :call, {:example, :foo, 0}, :arity, {0, 1000, 0}})
      Process.sleep(10)
      send(pid, {:trace_ts, self(), :out, {:example, :foo, 0}, {0, 1100, 0}})
      Process.sleep(10)
      send(pid, {:trace_ts, self(), :in, {:example, :foo, 0}, {0, 1500, 0}})
      Process.sleep(10)
      send(pid, {:trace_ts, self(), :return_to, {:example, :root, 0}, {0, 1600, 0}})
      Process.sleep(10)

      send(pid, :do_stop_trace)

      assert_receive {:phoenix, :send_update, {_, %{flame_on_update: root}}}, 500

      assert [foo] = root.children
      assert [sleep_block] = foo.children
      assert sleep_block.function == :sleep
      assert sleep_block.duration == 400_000_000
    end
  end

  defp build_config(opts \\ []) do
    %Config{
      module: Keyword.get(opts, :module, FlameOnTest.ExampleModule),
      function: Keyword.get(opts, :function, :foo),
      arity: Keyword.get(opts, :arity, 0),
      timeout: Keyword.get(opts, :timeout, 5000),
      target_node: Keyword.get(opts, :target_node, node()),
      reply_to: Keyword.get(opts, :reply_to, {:live_component, self(), "test"})
    }
  end
end
