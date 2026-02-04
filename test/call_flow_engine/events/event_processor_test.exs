defmodule CallFlowEngine.Events.EventProcessorTest do
  use CallFlowEngine.DataCase, async: false

  alias CallFlowEngine.Events.{EventProcessor, CallEvent, CallEventPayload}
  alias CallFlowEngine.Repo

  setup do
    # Restart EventProcessor to get clean state
    if pid = GenServer.whereis(EventProcessor) do
      GenServer.stop(pid, :normal)
      :timer.sleep(100)
    end
    
    {:ok, _pid} = start_supervised(EventProcessor)
    :ok
  end

  describe "process_event/1" do
    test "creates a call_event record in database" do
      payload = %CallEventPayload{
        call_id: "test-call-123",
        event_type: "stasis_start",
        direction: :inbound,
        caller_number: "+1234567890",
        callee_number: "9091",
        raw_payload: %{},
        occurred_at: DateTime.utc_now()
      }

      assert :ok = EventProcessor.process_event_sync(payload)

      events = Repo.all(CallEvent)
      assert length(events) == 1
      
      event = List.first(events)
      assert event.call_id == "test-call-123"
      assert event.event_type == "stasis_start"
    end

    test "increments total_events counter" do
      initial_stats = EventProcessor.get_stats()
      initial_count = initial_stats.total_events

      payload = %CallEventPayload{
        call_id: "test-call-456",
        event_type: "state_change",
        direction: :inbound,
        raw_payload: %{},
        occurred_at: DateTime.utc_now()
      }

      EventProcessor.process_event(payload)

      new_stats = EventProcessor.get_stats()
      assert new_stats.total_events == initial_count + 1
    end

    test "updates events_per_type statistics" do
      payload = %CallEventPayload{
        call_id: "test-call-789",
        event_type: "stasis_start",
        direction: :inbound,
        raw_payload: %{},
        occurred_at: DateTime.utc_now()
      }

      EventProcessor.process_event(payload)

      stats = EventProcessor.get_stats()
      assert stats.events_per_type["stasis_start"] == 1
    end

    test "updates events_per_call statistics" do
      payload = %CallEventPayload{
        call_id: "test-call-101",
        event_type: "stasis_start",
        direction: :inbound,
        raw_payload: %{},
        occurred_at: DateTime.utc_now()
      }

      EventProcessor.process_event(payload)
      EventProcessor.process_event(payload)

      stats = EventProcessor.get_stats()
      assert stats.events_per_call["test-call-101"] == 2
    end

    test "does not crash on database error" do
      # Test with invalid data that might cause DB error
      payload = %CallEventPayload{
        call_id: nil,  # This should cause validation error
        event_type: "test",
        direction: :unknown,
        raw_payload: %{},
        occurred_at: DateTime.utc_now()
      }

      # Should not crash, but return error
      result = EventProcessor.process_event(payload)
      assert {:error, _} = result

      # EventProcessor should still be alive
      assert Process.alive?(GenServer.whereis(EventProcessor))
    end
  end

  describe "get_stats/0" do
    test "returns statistics in correct format" do
      stats = EventProcessor.get_stats()
      
      assert is_map(stats)
      assert Map.has_key?(stats, :total_events)
      assert Map.has_key?(stats, :events_per_type)
      assert Map.has_key?(stats, :events_per_call)
    end
  end
end
