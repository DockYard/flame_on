defmodule FlameOn.Capture do
  @output_directory "flame_on_output_delete_me"
  @check_interval 500

  def capture(module, function, arity, pid, id, timeout \\ 15_000) do
    File.rm_rf!(@output_directory)
    File.mkdir!(@output_directory)

    :eflambe.capture({module, function, arity}, 1, output_directory: @output_directory)
    watch_output_directory(pid, id, timeout)
  end

  def watch_output_directory(pid, id, timeout) do
    spawn(fn -> watch_output_directory_loop(pid, id, timeout) end)
  end

  defp watch_output_directory_loop(pid, id, timeout, count \\ 0) do
    case File.ls!(@output_directory) do
      [] ->
        if count * @check_interval <= timeout do
          :timer.sleep(@check_interval)
          watch_output_directory_loop(pid, id, timeout, count + 1)
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
