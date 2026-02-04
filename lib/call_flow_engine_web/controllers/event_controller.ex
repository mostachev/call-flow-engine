defmodule CallFlowEngineWeb.EventController do
  use Phoenix.Controller, formats: [:json]
  
  alias CallFlowEngine.Events.{EventProcessor, CallEventPayload}
  
  def create(conn, params) do
    with {:ok, call_id} <- Map.fetch(params, "call_id"),
         {:ok, event_type} <- Map.fetch(params, "event_type") do
      
      payload = Map.get(params, "payload", %{})
      
      test_event = %CallEventPayload{
        call_id: call_id,
        event_type: event_type,
        direction: parse_direction(payload["direction"]),
        channel: payload["channel"],
        caller_number: payload["caller"],
        callee_number: payload["callee"],
        state: payload["state"],
        raw_payload: payload,
        occurred_at: DateTime.utc_now()
      }
      
      case EventProcessor.process_event(test_event) do
        :ok ->
          conn
          |> put_status(:accepted)
          |> json(%{
            status: "accepted",
            call_id: call_id,
            event_type: event_type
          })
        
        {:error, reason} ->
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: inspect(reason)})
      end
    else
      :error ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Missing required fields: call_id, event_type"})
    end
  end

  defp parse_direction("inbound"), do: :inbound
  defp parse_direction("outbound"), do: :outbound
  defp parse_direction(_), do: :unknown
end
