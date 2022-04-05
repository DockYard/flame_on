defmodule FlameOn.Capture do
  alias FlameOn.Capture.Server
  alias FlameOn.Capture.Config

  def capture(%Config{} = config) do
    {:ok, _pid} = :erpc.call(config.target_node, Server, :start, [config])

    :ok
  end
end
