defmodule FlameOn.Capture do
  @output_directory "flame_on_output_delete_me"
  @check_interval 500

  def capture(module, function, arity, opts) do
    target_node = Keyword.get(opts, :target_node, Node.self())

    Node.spawn(target_node, __MODULE__, :__local_capture__, [
      self(),
      module,
      function,
      arity,
      opts
    ])

    receive do
      {:__local_capture_start__, :success} -> :ok
      {:__local_capture_start__, :error, error} -> raise "Node.spawn_link failed with error: #{inspect(error)}"
    after
      5_000 -> raise "__local_capture__ failed due to timeout"
    end
  end

  def __local_capture__(from, module, function, arity, opts) do
    reply_pid = Keyword.get(opts, :reply_pid, self())
    reply_id = Keyword.fetch!(opts, :reply_id)
    timeout = Keyword.get(opts, :timeout, 15_000)

    File.rm_rf!(@output_directory)
    File.mkdir!(@output_directory)

    :ok = :eflambe.capture({module, function, arity}, 1, output_directory: @output_directory)
    send(from, {:__local_capture_start__, :success})
    watch_output_directory(reply_pid, reply_id, timeout)
  rescue
    e -> send(from, {:__local_capture_start__, :error, e})
  end

  defp watch_output_directory(pid, id, timeout, count \\ 0) do
    case File.ls!(@output_directory) do
      [] ->
        if count * @check_interval <= timeout do
          :timer.sleep(@check_interval)
          watch_output_directory(pid, id, timeout, count + 1)
        else
          Phoenix.LiveView.send_update(pid, FlameOn.Component, id: id, flame_on_timed_out: true)
        end

      [file] ->
        :timer.sleep(1000)
        path = Path.join(@output_directory, file)
        contents = File.read!(path)
        File.rm_rf!(@output_directory)
        results = FlameOn.Parser.parse_bggg(contents)

        Phoenix.LiveView.send_update(pid, FlameOn.Component,
          id: id,
          flame_on_results: results
        )
    end
  end
end
