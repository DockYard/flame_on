defmodule FlameOn.MixProject do
  use Mix.Project

  def project do
    [
      app: :flame_on,
      version: "0.5.2",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore.exs",
        list_unused_filters: true,
        plt_file: {:no_warn, "plts/flame_on.plt"},
        plt_add_apps: [:ex_unit, :mix]
      ],
      docs: docs(),
      package: package(),
      source_url: "https://github.com/DockYard/flame_on"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs() do
    [
      main: "readme",
      assets: "assets/",
      extras: ["README.md"]
    ]
  end

  def description do
    "Add Flame graphs to Live Dashboard or your own LiveView"
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/DockYard/flame_on"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ets, "~> 0.9.0"},
      {:dialyxir, "~> 1.2.0", only: [:dev, :test], runtime: false},
      {:mix_test_watch, "~> 1.1.0", only: :dev, runtime: false},
      {:ex_doc, "~> 0.28.0", only: :dev, runtime: false},
      {:ecto, "~> 3.7"},
      {:meck, "~> 0.9.2"},
      {:gettext, "~> 0.21"},
      {:jason, "~> 1.0"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_live_dashboard, "~> 0.7.2"},
      {:phoenix_live_view, "~> 0.18.11"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
