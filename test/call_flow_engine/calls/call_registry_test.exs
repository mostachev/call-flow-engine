defmodule CallFlowEngine.Calls.CallRegistryTest do
  use CallFlowEngine.DataCase, async: false

  alias CallFlowEngine.Calls.{Call, CallRegistry}

  setup do
    # Clear cache before each test
    CallRegistry.clear()
    :ok
  end

  describe "get_call/1" do
    test "returns call from cache if present" do
      call = %Call{
        call_id: "cache-test-001",
        status: "ringing",
        direction: "inbound",
        started_at: DateTime.utc_now()
      }
      
      # Put in cache
      CallRegistry.put_call(call)
      
      # Should retrieve from cache (not DB)
      cached_call = CallRegistry.get_call("cache-test-001")
      assert cached_call.call_id == call.call_id
    end

    test "fetches from database on cache miss and stores in cache" do
      # Create call in DB
      call = %Call{}
      |> Call.changeset(%{
        call_id: "db-test-001",
        status: "finished",
        direction: "outbound",
        started_at: DateTime.utc_now()
      })
      |> Repo.insert!()

      # First call - cache miss, should fetch from DB
      fetched_call = CallRegistry.get_call("db-test-001")
      assert fetched_call.call_id == "db-test-001"

      # Second call - should hit cache
      cached_call = CallRegistry.get_call("db-test-001")
      assert cached_call.call_id == "db-test-001"
    end

    test "returns nil for non-existent call" do
      result = CallRegistry.get_call("nonexistent")
      assert result == nil
    end
  end

  describe "put_call/1" do
    test "stores call in cache" do
      call = %Call{
        call_id: "put-test-001",
        status: "answered",
        direction: "inbound",
        started_at: DateTime.utc_now()
      }
      
      assert :ok = CallRegistry.put_call(call)
      
      # Verify it's in cache
      cached = CallRegistry.get_call("put-test-001")
      assert cached.call_id == "put-test-001"
    end

    test "updates existing cache entry" do
      call_v1 = %Call{
        call_id: "update-test-001",
        status: "ringing",
        direction: "inbound",
        started_at: DateTime.utc_now()
      }
      
      CallRegistry.put_call(call_v1)
      
      # Update
      call_v2 = %Call{call_v1 | status: "answered"}
      CallRegistry.put_call(call_v2)
      
      # Should have updated version
      cached = CallRegistry.get_call("update-test-001")
      assert cached.status == "answered"
    end
  end

  describe "delete_call/1" do
    test "removes call from cache" do
      call = %Call{
        call_id: "delete-test-001",
        status: "finished",
        direction: "inbound",
        started_at: DateTime.utc_now()
      }
      
      CallRegistry.put_call(call)
      assert CallRegistry.get_call("delete-test-001") != nil
      
      CallRegistry.delete_call("delete-test-001")
      
      # Should not be in cache anymore (but might still be in DB)
      # So we can't check with get_call as it fetches from DB
      # Instead check ETS directly
      assert :ets.lookup(:call_registry, "delete-test-001") == []
    end
  end

  describe "clear/0" do
    test "removes all entries from cache" do
      # Add multiple calls
      for i <- 1..5 do
        call = %Call{
          call_id: "clear-test-#{i}",
          status: "ringing",
          direction: "inbound",
          started_at: DateTime.utc_now()
        }
        CallRegistry.put_call(call)
      end
      
      # Clear all
      CallRegistry.clear()
      
      # Verify cache is empty
      assert :ets.tab2list(:call_registry) == []
    end
  end

  describe "automatic cleanup" do
    test "old entries are eventually cleaned up" do
      # This test would require waiting or mocking time
      # For now, just verify the mechanism exists
      
      call = %Call{
        call_id: "cleanup-test-001",
        status: "finished",
        direction: "inbound",
        started_at: DateTime.utc_now()
      }
      
      CallRegistry.put_call(call)
      
      # Manually trigger cleanup (simulating 1 hour passing)
      # Insert with old timestamp
      old_timestamp = System.monotonic_time(:second) - 7200
      :ets.insert(:call_registry, {call.call_id, call, old_timestamp})
      
      # Send cleanup message
      send(Process.whereis(CallRegistry), :cleanup)
      :timer.sleep(100)
      
      # Old entry should be removed
      assert :ets.lookup(:call_registry, "cleanup-test-001") == []
    end
  end
end
