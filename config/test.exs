import Config

# Configure your database
config :call_flow_engine, CallFlowEngine.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "call_flow_engine_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :call_flow_engine, CallFlowEngineWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_at_least_64_bytes_long_for_testing_purposes_only",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# ARI configuration for test (will not connect in tests)
config :call_flow_engine, :ari,
  url: "ws://localhost:8088/ari/events",
  user: "test",
  password: "test",
  app_name: "callflow_test"

# Bitrix24 mock URL for testing
config :call_flow_engine, :bitrix_webhook_url, "http://localhost:9999/mock"
