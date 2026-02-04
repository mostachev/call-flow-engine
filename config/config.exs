import Config

config :call_flow_engine,
  ecto_repos: [CallFlowEngine.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :call_flow_engine, CallFlowEngineWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [json: CallFlowEngineWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: CallFlowEngine.PubSub,
  live_view: [signing_salt: "call_flow_secret"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Telemetry polling interval
config :call_flow_engine, CallFlowEngine.PeriodicTelemetry,
  enabled: true,
  interval: :timer.seconds(10)

# Import environment specific config
import_config "#{config_env()}.exs"
