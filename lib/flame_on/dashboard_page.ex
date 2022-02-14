defmodule FlameOn.DashboardPage do
  @moduledoc false
  use Phoenix.LiveDashboard.PageBuilder
  alias Phoenix.LiveDashboard.PageBuilder

  @impl PageBuilder
  def menu_link(_, _) do
    {:ok, "Flame On"}
  end

  @impl PageBuilder
  def render_page(_assigns) do
    {FlameOn.Component, %{id: :flame_on_component}}
  end
end
