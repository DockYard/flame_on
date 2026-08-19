defmodule FlameOnTest.DashboardRouter do
  @moduledoc false
  use Phoenix.Router
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug(:fetch_session)
  end

  pipeline :browser_with_csp_nonce do
    plug(:fetch_session)
    plug(:put_csp_nonce)
  end

  scope "/" do
    pipe_through(:browser)

    live_dashboard("/dashboard", additional_pages: [flame_on: FlameOn.DashboardPage])
  end

  scope "/" do
    pipe_through(:browser_with_csp_nonce)

    live_dashboard("/csp-dashboard",
      additional_pages: [flame_on: FlameOn.DashboardPage],
      csp_nonce_assign_key: :csp_nonce,
      live_session_name: :live_dashboard_csp
    )
  end

  defp put_csp_nonce(conn, _opts), do: Plug.Conn.assign(conn, :csp_nonce, "flame-on-test-nonce")
end

defmodule FlameOnTest.DashboardEndpoint do
  @moduledoc false
  use Phoenix.Endpoint, otp_app: :flame_on

  plug(Plug.Session, store: :cookie, key: "_flame_on_test_key", signing_salt: "flame_on_test_salt")
  plug(FlameOnTest.DashboardRouter)
end
