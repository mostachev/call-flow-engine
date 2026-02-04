defmodule CallFlowEngineWeb.HealthController do
  use Phoenix.Controller, formats: [:json]
  
  alias CallFlowEngine.Repo
  
  def index(conn, _params) do
    db_status = check_db()
    ari_status = check_ari_connection()
    
    json(conn, %{
      status: "ok",
      db: db_status,
      ari_connection: ari_status,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  defp check_db do
    case Ecto.Adapters.SQL.query(Repo, "SELECT 1", []) do
      {:ok, _} -> "ok"
      {:error, _} -> "error"
    end
  rescue
    _ -> "error"
  end

  defp check_ari_connection do
    case GenServer.whereis(CallFlowEngine.Ari.Connection) do
      nil -> "disconnected"
      pid when is_pid(pid) -> "connected"
    end
  end
end
