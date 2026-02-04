defmodule CallFlowEngineWeb.EventControllerTest do
  use CallFlowEngineWeb.ConnCase, async: true

  alias CallFlowEngine.Events.CallEvent

  describe "POST /api/test/events" do
    test "creates event in database", %{conn: conn} do
      params = %{
        "call_id" => "test-event-001",
        "event_type" => "stasis_start",
        "payload" => %{
          "caller" => "+1234567890",
          "callee" => "9091",
          "direction" => "inbound"
        }
      }

      conn = post(conn, ~p"/api/test/events", params)
      
      assert json_response(conn, 202) == %{
        "status" => "accepted",
        "call_id" => "test-event-001",
        "event_type" => "stasis_start"
      }

      # Verify event was persisted
      events = Repo.all(CallEvent)
      assert Enum.any?(events, fn e -> e.call_id == "test-event-001" end)
    end

    test "updates statistics after event", %{conn: conn} do
      # Get initial stats
      stats_conn = get(conn, ~p"/api/stats")
      initial_stats = json_response(stats_conn, 200)
      initial_count = initial_stats["total_events"]

      # Create event
      params = %{
        "call_id" => "test-event-002",
        "event_type" => "state_change",
        "payload" => %{}
      }

      post(conn, ~p"/api/test/events", params)

      # Check updated stats
      stats_conn = get(conn, ~p"/api/stats")
      new_stats = json_response(stats_conn, 200)
      
      assert new_stats["total_events"] == initial_count + 1
    end

    test "returns 400 when missing required fields", %{conn: conn} do
      params = %{"call_id" => "incomplete"}
      
      conn = post(conn, ~p"/api/test/events", params)
      
      assert json_response(conn, 400) == %{
        "error" => "Missing required fields: call_id, event_type"
      }
    end
  end
end
