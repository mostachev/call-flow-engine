import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere.

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :call_flow_engine, CallFlowEngine.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :call_flow_engine, CallFlowEngineWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ARI configuration (optional - will run in mock mode if not set)
  ari_url = System.get_env("ARI_URL")
  ari_user = System.get_env("ARI_USER")
  ari_password = System.get_env("ARI_PASSWORD")
  
  if ari_url && ari_user && ari_password do
    config :call_flow_engine, :ari,
      url: ari_url,
      user: ari_user,
      password: ari_password,
      app_name: System.get_env("ARI_APP_NAME") || "callflow_elixir"
  else
    Logger.warning("ARI configuration incomplete - will run in mock mode")
    config :call_flow_engine, :ari, []
  end

  # Bitrix24 webhook URL (optional)
  if bitrix_url = System.get_env("BITRIX_WEBHOOK_URL") do
    config :call_flow_engine, :bitrix_webhook_url, bitrix_url
  else
    Logger.warning("BITRIX_WEBHOOK_URL not set - Bitrix integration disabled")
    config :call_flow_engine, :bitrix_webhook_url, nil
  end

  # Log level
  config :logger, level: String.to_atom(System.get_env("LOG_LEVEL") || "info")
end
