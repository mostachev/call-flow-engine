defmodule CallFlowEngineWeb.StatsControllerTest do
  use CallFlowEngineWeb.ConnCase, async: false

  alias CallFlowEngine.Events.{EventProcessor, CallEventPayload}

  setup do
    # Restart EventProcessor for clean state
    if pid = GenServer.whereis(EventProcessor) do
      GenServer.stop(pid, :normal)
      :timer.sleep(100)
    end
    
    {:ok, _pid} = start_supervised(EventProcessor)
    :ok
  end

  describe "GET /api/stats" do
    test "returns statistics with correct structure", %{conn: conn} do
      conn = get(conn, ~p"/api/stats")
      response = json_response(conn, 200)
      
      assert Map.has_key?(response, "total_events")
      assert Map.has_key?(response, "events_per_type")
      assert Map.has_key?(response, "events_per_call")
    end

    test "reflects processed events", %{conn: conn} do
      # Process a test event
      payload = %CallEventPayload{
        call_id: "stats-test-001",
        event_type: "stasis_start",
        direction: :inbound,
        raw_payload: %{},
        occurred_at: DateTime.utc_now()
      }
      
      EventProcessor.process_event_sync(payload)

      conn = get(conn, ~p"/api/stats")
      response = json_response(conn, 200)
      
      assert response["total_events"] >= 1
      assert response["events_per_type"]["stasis_start"] >= 1
    end
  end
end
