defmodule FlameOn.MixProject do
  use Mix.Project

  def project do
    [
      app: :flame_on,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:mix_test_watch, "~> 1.1.0", only: :dev, runtime: false},
      {:ecto, "~> 3.7"},
      {:eflambe, "~> 0.2.2"},
      {:gettext, "~> 0.19"},
      {:jason, "~> 1.0"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_live_dashboard, "~> 0.6.4"},
      {:phoenix_live_view, "~> 0.17.6"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
