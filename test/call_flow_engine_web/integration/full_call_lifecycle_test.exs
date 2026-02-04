defmodule CallFlowEngineWeb.Integration.FullCallLifecycleTest do
  use CallFlowEngineWeb.ConnCase, async: false

  alias CallFlowEngine.Calls.{Call, CallService}
  alias CallFlowEngine.Events.CallEvent

  setup do
    bypass = Bypass.open()
    Application.put_env(:call_flow_engine, :bitrix_webhook_url, "http://localhost:#{bypass.port}")
    
    {:ok, bypass: bypass}
  end

  describe "Full call lifecycle via test events" do
    test "stasis_start -> state_change (Up) -> stasis_end creates complete call", %{conn: conn, bypass: bypass} do
      call_id = "lifecycle-test-#{System.unique_integer([:positive])}"

      # Mock Bitrix24 responses
      Bypass.expect(bypass, "POST", "/telephony.externalcall.register", fn conn ->
        Plug.Conn.resp(conn, 200, Jason.encode!(%{result: "ok"}))
      end)

      Bypass.expect(bypass, "POST", "/telephony.externalcall.finish", fn conn ->
        Plug.Conn.resp(conn, 200, Jason.encode!(%{result: "ok"}))
      end)

      # Step 1: Send stasis_start event
      stasis_start = %{
        "call_id" => call_id,
        "event_type" => "stasis_start",
        "payload" => %{
          "caller" => "+1234567890",
          "callee" => "9091",
          "direction" => "inbound"
        }
      }

      conn1 = post(conn, ~p"/api/test/events", stasis_start)
      assert json_response(conn1, 202)["status"] == "accepted"

      # Wait for async processing
      :timer.sleep(100)

      # Verify call was created
      call = CallService.get_call(call_id)
      assert call != nil
      assert call.status == "ringing"
      assert call.caller_number == "+1234567890"
      assert call.callee_number == "9091"
      assert call.direction == "inbound"

      # Step 2: Send state_change Up event
      state_change = %{
        "call_id" => call_id,
        "event_type" => "state_change",
        "payload" => %{
          "state" => "Up"
        }
      }

      conn2 = post(conn, ~p"/api/test/events", state_change)
      assert json_response(conn2, 202)["status"] == "accepted"

      :timer.sleep(100)

      # Verify call was answered
      call = CallService.get_call(call_id)
      assert call.status == "answered"
      assert call.answered_at != nil

      # Step 3: Send stasis_end event
      stasis_end = %{
        "call_id" => call_id,
        "event_type" => "stasis_end",
        "payload" => %{}
      }

      conn3 = post(conn, ~p"/api/test/events", stasis_end)
      assert json_response(conn3, 202)["status"] == "accepted"

      :timer.sleep(200)

      # Verify call was finished
      call = CallService.get_call(call_id)
      assert call.status == "finished"
      assert call.ended_at != nil
      assert DateTime.compare(call.ended_at, call.answered_at) in [:gt, :eq]

      # Verify all 3 events were created
      events = Repo.all(from e in CallEvent, where: e.call_id == ^call_id)
      assert length(events) == 3
      
      event_types = Enum.map(events, & &1.event_type) |> Enum.sort()
      assert event_types == ["stasis_end", "stasis_start", "state_change"]
    end

    test "call duration is calculated correctly", %{conn: conn, bypass: bypass} do
      call_id = "duration-test-#{System.unique_integer([:positive])}"

      Bypass.expect(bypass, "POST", "/telephony.externalcall.register", fn conn ->
        Plug.Conn.resp(conn, 200, Jason.encode!(%{result: "ok"}))
      end)

      Bypass.expect(bypass, "POST", "/telephony.externalcall.finish", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        data = Jason.decode!(body)
        
        # Duration should be > 0
        assert data["DURATION"] > 0
        
        Plug.Conn.resp(conn, 200, Jason.encode!(%{result: "ok"}))
      end)

      # Create call sequence
      post(conn, ~p"/api/test/events", %{
        "call_id" => call_id,
        "event_type" => "stasis_start",
        "payload" => %{"direction" => "inbound"}
      })
      
      :timer.sleep(100)

      post(conn, ~p"/api/test/events", %{
        "call_id" => call_id,
        "event_type" => "state_change",
        "payload" => %{"state" => "Up"}
      })
      
      # Wait some time for duration
      :timer.sleep(2000)

      post(conn, ~p"/api/test/events", %{
        "call_id" => call_id,
        "event_type" => "stasis_end",
        "payload" => %{}
      })
      
      :timer.sleep(200)

      call = CallService.get_call(call_id)
      duration = DateTime.diff(call.ended_at, call.answered_at)
      assert duration >= 2
    end
  end

  describe "Error handling in call lifecycle" do
    test "Bitrix24 error does not prevent call processing", %{conn: conn, bypass: bypass} do
      call_id = "error-test-#{System.unique_integer([:positive])}"

      # Mock Bitrix24 to return error
      Bypass.expect(bypass, "POST", "/telephony.externalcall.register", fn conn ->
        Plug.Conn.resp(conn, 500, "Internal Server Error")
      end)

      # Event should still be processed despite Bitrix error
      conn = post(conn, ~p"/api/test/events", %{
        "call_id" => call_id,
        "event_type" => "stasis_start",
        "payload" => %{"direction" => "inbound"}
      })

      assert json_response(conn, 202)["status"] == "accepted"
      
      :timer.sleep(200)

      # Call should still be created
      call = CallService.get_call(call_id)
      assert call != nil
      assert call.status == "ringing"
    end
  end
end
