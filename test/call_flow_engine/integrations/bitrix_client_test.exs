defmodule CallFlowEngine.Integrations.BitrixClientTest do
  use ExUnit.Case, async: true

  alias CallFlowEngine.Integrations.BitrixClient
  alias CallFlowEngine.Calls.Call

  setup do
    bypass = Bypass.open()
    
    # Configure mock webhook URL
    Application.put_env(:call_flow_engine, :bitrix_webhook_url, "http://localhost:#{bypass.port}")
    
    {:ok, bypass: bypass}
  end

  describe "register_call/1" do
    test "sends POST request with correct payload", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/telephony.externalcall.register", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        data = Jason.decode!(body)
        
        assert data["CALL_ID"] == "test-call-001"
        assert data["PHONE_NUMBER"] == "+1234567890"
        assert data["TYPE"] == 1
        
        Plug.Conn.resp(conn, 200, Jason.encode!(%{result: "ok"}))
      end)

      call = %Call{
        call_id: "test-call-001",
        direction: "inbound",
        caller_number: "+1234567890",
        callee_number: "9091",
        status: "ringing",
        started_at: DateTime.utc_now()
      }

      assert :ok = BitrixClient.register_call(call)
    end

    test "retries on HTTP 500 error", %{bypass: bypass} do
      # Track number of requests
      test_pid = self()
      
      Bypass.expect(bypass, "POST", "/telephony.externalcall.register", fn conn ->
        send(test_pid, :request_received)
        Plug.Conn.resp(conn, 500, "Internal Server Error")
      end)

      call = %Call{
        call_id: "test-call-002",
        direction: "inbound",
        status: "ringing",
        started_at: DateTime.utc_now()
      }

      BitrixClient.register_call(call)

      # Should receive at least 2 requests (original + 1 retry)
      assert_receive :request_received, 2000
      assert_receive :request_received, 2000
    end

    test "returns error after retries exhausted", %{bypass: bypass} do
      Bypass.expect(bypass, "POST", "/telephony.externalcall.register", fn conn ->
        Plug.Conn.resp(conn, 500, "Internal Server Error")
      end)

      call = %Call{
        call_id: "test-call-003",
        direction: "inbound",
        status: "ringing",
        started_at: DateTime.utc_now()
      }

      result = BitrixClient.register_call(call)
      assert {:error, _} = result
    end
  end

  describe "finish_call/1" do
    test "sends POST request with duration and status", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/telephony.externalcall.finish", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        data = Jason.decode!(body)
        
        assert data["CALL_ID"] == "test-call-101"
        assert data["DURATION"] == 60
        assert data["STATUS_CODE"] == 200
        
        Plug.Conn.resp(conn, 200, Jason.encode!(%{result: "ok"}))
      end)

      answered_at = DateTime.utc_now()
      ended_at = DateTime.add(answered_at, 60, :second)

      call = %Call{
        call_id: "test-call-101",
        direction: "inbound",
        status: "finished",
        started_at: DateTime.add(answered_at, -5, :second),
        answered_at: answered_at,
        ended_at: ended_at
      }

      assert :ok = BitrixClient.finish_call(call)
    end

    test "handles timeout with retry", %{bypass: bypass} do
      test_pid = self()
      
      Bypass.expect(bypass, "POST", "/telephony.externalcall.finish", fn conn ->
        send(test_pid, :request_received)
        # Simulate timeout by not responding
        Process.sleep(6000)
        Plug.Conn.resp(conn, 200, "OK")
      end)

      call = %Call{
        call_id: "test-call-102",
        status: "finished",
        started_at: DateTime.utc_now(),
        answered_at: DateTime.utc_now(),
        ended_at: DateTime.utc_now()
      }

      # Should timeout and retry
      BitrixClient.finish_call(call)
      
      assert_receive :request_received, 7000
    end
  end
end
