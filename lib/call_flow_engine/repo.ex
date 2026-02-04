defmodule CallFlowEngine.Repo do
  use Ecto.Repo,
    otp_app: :call_flow_engine,
    adapter: Ecto.Adapters.Postgres
end
