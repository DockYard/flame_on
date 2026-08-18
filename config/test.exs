import Config

config :logger, level: :warning

config :flame_on, FlameOnTest.DashboardEndpoint,
  secret_key_base: String.duplicate("a", 64),
  live_view: [signing_salt: "flame_on_test_salt"],
  server: false
