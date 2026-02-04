defmodule CallFlowEngineWeb.HealthControllerTest do
  use CallFlowEngineWeb.ConnCase, async: true

  describe "GET /health" do
    test "returns status ok with system information", %{conn: conn} do
      conn = get(conn, ~p"/health")
      
      assert json_response(conn, 200) == %{
        "status" => "ok",
        "db" => "ok",
        "ari_connection" => "connected",
        "timestamp" => conn.resp_body |> Jason.decode!() |> Map.get("timestamp")
      }
    end

    test "includes timestamp in response", %{conn: conn} do
      conn = get(conn, ~p"/health")
      response = json_response(conn, 200)
      
      assert Map.has_key?(response, "timestamp")
      assert is_binary(response["timestamp"])
    end
  end
end
