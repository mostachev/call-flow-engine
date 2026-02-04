defmodule CallFlowEngineWeb.CallController do
  use Phoenix.Controller, formats: [:json]
  
  alias CallFlowEngine.Calls.CallService
  
  def index(conn, params) do
    filters = %{}
    
    filters = if params["status"], do: Map.put(filters, :status, params["status"]), else: filters
    filters = if params["direction"], do: Map.put(filters, :direction, params["direction"]), else: filters
    filters = if params["limit"], do: Map.put(filters, :limit, String.to_integer(params["limit"])), else: filters
    
    calls = CallService.list_calls(filters)
    
    json(conn, calls)
  end

  def show(conn, %{"id" => id}) do
    case CallService.get_call_with_events(id) do
      {:ok, call, events} ->
        json(conn, %{
          call: call,
          events: events
        })
      
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Call not found"})
    end
  end
end
