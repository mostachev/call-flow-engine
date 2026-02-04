defmodule CallFlowEngineWeb.StatsController do
  use Phoenix.Controller, formats: [:json]
  
  alias CallFlowEngine.Events.EventProcessor
  
  def index(conn, _params) do
    stats = EventProcessor.get_stats()
    json(conn, stats)
  end
end
