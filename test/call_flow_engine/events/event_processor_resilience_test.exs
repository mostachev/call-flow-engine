defmodule CallFlowEngine.Events.EventProcessorResilienceTest do
  use CallFlowEngine.DataCase, async: false

  alias CallFlowEngine.Events.{EventProcessor, CallEventPayload}

  describe "Supervisor resilience" do
    test "EventProcessor restarts after crash" do
      # Get initial PID
      initial_pid = GenServer.whereis(EventProcessor)
      assert initial_pid != nil
      assert Process.alive?(initial_pid)

      # Kill the process
      Process.exit(initial_pid, :kill)
      
      # Wait for supervisor to restart it
      :timer.sleep(500)

      # Get new PID
      new_pid = GenServer.whereis(EventProcessor)
      assert new_pid != nil
      assert Process.alive?(new_pid)
      assert new_pid != initial_pid
    end

    test "EventProcessor continues processing events after restart" do
      # Get initial PID and process an event
      initial_pid = GenServer.whereis(EventProcessor)
      
      payload1 = %CallEventPayload{
        call_id: "resilience-test-001",
        event_type: "stasis_start",
        direction: :inbound,
        raw_payload: %{},
        occurred_at: DateTime.utc_now()
      }
      
      assert :ok = EventProcessor.process_event_sync(payload1)

      # Kill and wait for restart
      Process.exit(initial_pid, :kill)
      :timer.sleep(500)

      # Process another event with the new process
      payload2 = %CallEventPayload{
        call_id: "resilience-test-002",
        event_type: "stasis_start",
        direction: :inbound,
        raw_payload: %{},
        occurred_at: DateTime.utc_now()
      }
      
      # Should process successfully
      assert :ok = EventProcessor.process_event_sync(payload2)

      # Verify both events were persisted
      events = Repo.all(CallFlowEngine.Events.CallEvent)
      call_ids = Enum.map(events, & &1.call_id)
      
      assert "resilience-test-001" in call_ids
      assert "resilience-test-002" in call_ids
    end

    test "statistics are reset after restart" do
      # Process event to build up stats
      payload = %CallEventPayload{
        call_id: "resilience-test-003",
        event_type: "stasis_start",
        direction: :inbound,
        raw_payload: %{},
        occurred_at: DateTime.utc_now()
      }
      
      EventProcessor.process_event_sync(payload)
      
      stats_before = EventProcessor.get_stats()
      assert stats_before.total_events > 0

      # Kill and restart
      pid = GenServer.whereis(EventProcessor)
      Process.exit(pid, :kill)
      :timer.sleep(500)

      # Stats should be reset (in-memory state is lost)
      stats_after = EventProcessor.get_stats()
      assert stats_after.total_events == 0
      assert stats_after.events_per_type == %{}
      assert stats_after.events_per_call == %{}
    end
  end
end
