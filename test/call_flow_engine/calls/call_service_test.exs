defmodule CallFlowEngine.Calls.CallServiceTest do
  use CallFlowEngine.DataCase, async: true

  alias CallFlowEngine.Calls.{Call, CallService}
  alias CallFlowEngine.Events.CallEventPayload

  describe "handle_event/1 with stasis_start" do
    test "creates a new call with ringing status" do
      payload = %CallEventPayload{
        call_id: "call-1001",
        event_type: "stasis_start",
        direction: :inbound,
        caller_number: "+1234567890",
        callee_number: "9091",
        raw_payload: %{},
        occurred_at: DateTime.utc_now()
      }

      assert {:ok, call} = CallService.handle_event(payload)
      assert call.call_id == "call-1001"
      assert call.status == "ringing"
      assert call.direction == "inbound"
      assert call.caller_number == "+1234567890"
      assert call.callee_number == "9091"
    end

    test "does not create duplicate call for same call_id" do
      payload = %CallEventPayload{
        call_id: "call-1002",
        event_type: "stasis_start",
        direction: :inbound,
        raw_payload: %{},
        occurred_at: DateTime.utc_now()
      }

      {:ok, call1} = CallService.handle_event(payload)
      {:ok, call2} = CallService.handle_event(payload)

      assert call1.id == call2.id
    end
  end

  describe "handle_event/1 with state_change Up" do
    test "updates call to answered status with answered_at timestamp" do
      # First create a call
      start_time = DateTime.utc_now()
      start_payload = %CallEventPayload{
        call_id: "call-2001",
        event_type: "stasis_start",
        direction: :inbound,
        raw_payload: %{},
        occurred_at: start_time
      }
      
      {:ok, _call} = CallService.handle_event(start_payload)

      # Then answer it
      answer_time = DateTime.add(start_time, 5, :second)
      answer_payload = %CallEventPayload{
        call_id: "call-2001",
        event_type: "state_change",
        state: "Up",
        direction: :inbound,
        raw_payload: %{},
        occurred_at: answer_time
      }

      {:ok, call} = CallService.handle_event(answer_payload)
      
      assert call.status == "answered"
      assert call.answered_at != nil
      assert DateTime.compare(call.answered_at, start_time) == :gt
    end
  end

  describe "handle_event/1 with stasis_end" do
    test "updates call to finished status with ended_at timestamp" do
      # Create and answer a call
      start_time = DateTime.utc_now()
      
      start_payload = %CallEventPayload{
        call_id: "call-3001",
        event_type: "stasis_start",
        direction: :inbound,
        raw_payload: %{},
        occurred_at: start_time
      }
      CallService.handle_event(start_payload)

      answer_payload = %CallEventPayload{
        call_id: "call-3001",
        event_type: "state_change",
        state: "Up",
        direction: :inbound,
        raw_payload: %{},
        occurred_at: DateTime.add(start_time, 2, :second)
      }
      CallService.handle_event(answer_payload)

      # End the call
      end_time = DateTime.add(start_time, 60, :second)
      end_payload = %CallEventPayload{
        call_id: "call-3001",
        event_type: "stasis_end",
        direction: :inbound,
        raw_payload: %{},
        occurred_at: end_time
      }

      {:ok, call} = CallService.handle_event(end_payload)
      
      assert call.status == "finished"
      assert call.ended_at != nil
      assert DateTime.diff(call.ended_at, call.answered_at) > 0
    end
  end

  describe "list_calls/1" do
    test "returns calls filtered by status" do
      # Create calls with different statuses
      %Call{}
      |> Call.changeset(%{
        call_id: "call-4001",
        status: "ringing",
        direction: "inbound",
        started_at: DateTime.utc_now()
      })
      |> Repo.insert!()

      %Call{}
      |> Call.changeset(%{
        call_id: "call-4002",
        status: "finished",
        direction: "inbound",
        started_at: DateTime.utc_now()
      })
      |> Repo.insert!()

      calls = CallService.list_calls(%{status: "ringing"})
      
      assert length(calls) == 1
      assert List.first(calls).status == "ringing"
    end

    test "returns calls filtered by direction" do
      %Call{}
      |> Call.changeset(%{
        call_id: "call-5001",
        status: "finished",
        direction: "inbound",
        started_at: DateTime.utc_now()
      })
      |> Repo.insert!()

      %Call{}
      |> Call.changeset(%{
        call_id: "call-5002",
        status: "finished",
        direction: "outbound",
        started_at: DateTime.utc_now()
      })
      |> Repo.insert!()

      calls = CallService.list_calls(%{direction: "outbound"})
      
      assert length(calls) == 1
      assert List.first(calls).direction == "outbound"
    end
  end

  describe "get_call_with_events/1" do
    test "returns call with its events" do
      alias CallFlowEngine.Events.CallEvent
      
      call = %Call{}
      |> Call.changeset(%{
        call_id: "call-6001",
        status: "finished",
        direction: "inbound",
        started_at: DateTime.utc_now()
      })
      |> Repo.insert!()

      # Create events for this call
      %CallEvent{}
      |> CallEvent.changeset(%{
        call_id: "call-6001",
        event_type: "stasis_start",
        payload: %{},
        occurred_at: DateTime.utc_now()
      })
      |> Repo.insert!()

      {:ok, retrieved_call, events} = CallService.get_call_with_events("call-6001")
      
      assert retrieved_call.id == call.id
      assert length(events) == 1
    end
  end
end
