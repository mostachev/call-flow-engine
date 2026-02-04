defmodule CallFlowEngineWeb.CallControllerTest do
  use CallFlowEngineWeb.ConnCase, async: true

  alias CallFlowEngine.Calls.Call

  describe "GET /api/calls" do
    test "returns list of calls", %{conn: conn} do
      # Create test calls
      %Call{}
      |> Call.changeset(%{
        call_id: "api-call-001",
        status: "finished",
        direction: "inbound",
        started_at: DateTime.utc_now()
      })
      |> Repo.insert!()

      conn = get(conn, ~p"/api/calls")
      response = json_response(conn, 200)
      
      assert is_list(response)
      assert length(response) > 0
    end

    test "filters calls by status", %{conn: conn} do
      %Call{}
      |> Call.changeset(%{
        call_id: "api-call-002",
        status: "ringing",
        direction: "inbound",
        started_at: DateTime.utc_now()
      })
      |> Repo.insert!()

      %Call{}
      |> Call.changeset(%{
        call_id: "api-call-003",
        status: "finished",
        direction: "inbound",
        started_at: DateTime.utc_now()
      })
      |> Repo.insert!()

      conn = get(conn, ~p"/api/calls?status=ringing")
      response = json_response(conn, 200)
      
      assert Enum.all?(response, fn call -> call["status"] == "ringing" end)
    end

    test "filters calls by direction", %{conn: conn} do
      %Call{}
      |> Call.changeset(%{
        call_id: "api-call-004",
        status: "finished",
        direction: "outbound",
        started_at: DateTime.utc_now()
      })
      |> Repo.insert!()

      conn = get(conn, ~p"/api/calls?direction=outbound")
      response = json_response(conn, 200)
      
      assert Enum.all?(response, fn call -> call["direction"] == "outbound" end)
    end
  end

  describe "GET /api/calls/:id" do
    test "returns call with events", %{conn: conn} do
      alias CallFlowEngine.Events.CallEvent
      
      call = %Call{}
      |> Call.changeset(%{
        call_id: "api-call-005",
        status: "finished",
        direction: "inbound",
        started_at: DateTime.utc_now()
      })
      |> Repo.insert!()

      # Create event for this call
      %CallEvent{}
      |> CallEvent.changeset(%{
        call_id: "api-call-005",
        event_type: "stasis_start",
        payload: %{},
        occurred_at: DateTime.utc_now()
      })
      |> Repo.insert!()

      conn = get(conn, ~p"/api/calls/api-call-005")
      response = json_response(conn, 200)
      
      assert Map.has_key?(response, "call")
      assert Map.has_key?(response, "events")
      assert response["call"]["call_id"] == "api-call-005"
      assert is_list(response["events"])
    end

    test "returns 404 for non-existent call", %{conn: conn} do
      conn = get(conn, ~p"/api/calls/non-existent")
      
      assert json_response(conn, 404) == %{
        "error" => "Call not found"
      }
    end
  end
end
