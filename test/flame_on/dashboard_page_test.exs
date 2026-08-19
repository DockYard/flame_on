defmodule FlameOn.DashboardPageTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias FlameOnTest.DashboardEndpoint

  @endpoint DashboardEndpoint

  setup do
    start_supervised!(DashboardEndpoint)
    {:ok, conn: build_conn()}
  end

  test "adds a Flame On entry to the LiveDashboard menu", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/dashboard/flame_on")

    assert render(view) =~ ~s(<div class="menu-item active">Flame On</div>)
  end

  test "renders the capture form for the dashboard's selected node", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/dashboard/flame_on")
    html = render(view)

    assert html =~ ~s(phx-submit="capture_schema")

    for field <- ~w(module function arity timeout) do
      assert html =~ ~s(name="capture_schema[#{field}]")
    end
  end

  test "applies the dashboard's CSP nonce to the inline style", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/csp-dashboard/flame_on")

    assert render(view) =~ ~s(<style nonce="flame-on-test-nonce">)
  end
end
