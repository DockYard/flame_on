defmodule FlameOn.Capture do
  alias FlameOn.Capture.Server
  alias FlameOn.Capture.Config

  def capture(%Config{} = config) do
    case :erpc.call(config.target_node, Server, :start, [config]) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _}} -> :ok
      _ -> :error
    end
  end
end
