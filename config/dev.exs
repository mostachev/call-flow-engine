import Config

# Configure your database
config :call_flow_engine, CallFlowEngine.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "call_flow_engine_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
config :call_flow_engine, CallFlowEngineWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "development_secret_key_base_at_least_64_bytes_long_please_change_me",
  watchers: []

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# ARI configuration for development
config :call_flow_engine, :ari,
  url: System.get_env("ARI_URL") || "ws://localhost:8088/ari/events",
  user: System.get_env("ARI_USER") || "asterisk",
  password: System.get_env("ARI_PASSWORD") || "asterisk",
  app_name: System.get_env("ARI_APP_NAME") || "callflow_elixir"

# Bitrix24 webhook URL
config :call_flow_engine, :bitrix_webhook_url,
  System.get_env("BITRIX_WEBHOOK_URL") || "http://localhost:9999/mock"
