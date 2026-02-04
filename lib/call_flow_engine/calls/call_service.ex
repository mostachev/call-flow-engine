defmodule CallFlowEngine.Calls.CallService do
  @moduledoc """
  Business logic for managing call lifecycle and state transitions.
  """

  require Logger
  
  alias CallFlowEngine.Calls.Call
  alias CallFlowEngine.Events.CallEventPayload
  alias CallFlowEngine.Integrations.BitrixClient
  alias CallFlowEngine.Repo

  import Ecto.Query

  @doc """
  Handles a call event and updates call state accordingly.
  """
  def handle_event(%CallEventPayload{event_type: "stasis_start"} = payload) do
    # Use CallRegistry for fast lookup (ETS cache)
    case CallFlowEngine.Calls.CallRegistry.get_call(payload.call_id) do
      nil -> create_call(payload)
      call -> {:ok, call}
    end
  end

  def handle_event(%CallEventPayload{event_type: "state_change", state: "Up"} = payload) do
    case CallFlowEngine.Calls.CallRegistry.get_call(payload.call_id) do
      nil -> 
        Logger.warning("Received state_change for unknown call #{payload.call_id}")
        {:error, :call_not_found}
      
      call -> answer_call(call, payload)
    end
  end

  def handle_event(%CallEventPayload{event_type: "stasis_end"} = payload) do
    case CallFlowEngine.Calls.CallRegistry.get_call(payload.call_id) do
      nil -> 
        Logger.warning("Received stasis_end for unknown call #{payload.call_id}")
        {:error, :call_not_found}
      
      call -> finish_call(call, payload)
    end
  end

  def handle_event(%CallEventPayload{event_type: "channel_destroyed"} = payload) do
    case CallFlowEngine.Calls.CallRegistry.get_call(payload.call_id) do
      nil -> {:error, :call_not_found}
      call -> finish_call(call, payload)
    end
  end

  def handle_event(%CallEventPayload{event_type: "var_set"} = payload) do
    # Handle channel variable updates if needed
    case CallFlowEngine.Calls.CallRegistry.get_call(payload.call_id) do
      nil -> {:error, :call_not_found}
      call -> update_call_variables(call, payload)
    end
  end

  def handle_event(%CallEventPayload{} = _payload) do
    # Handle other event types or ignore
    :ok
  end

  # Private Functions

  defp create_call(payload) do
    direction = case payload.direction do
      :inbound -> "inbound"
      :outbound -> "outbound"
      _ -> "unknown"
    end

    attrs = %{
      call_id: payload.call_id,
      direction: direction,
      caller_number: payload.caller_number,
      callee_number: payload.callee_number,
      status: "ringing",
      started_at: payload.occurred_at
    }

    # Use upsert to handle race conditions
    case %Call{}
         |> Call.changeset(attrs)
         |> Repo.insert(on_conflict: :nothing, conflict_target: :call_id) do
      {:ok, call} ->
        Logger.info("Created call #{call.call_id} with status #{call.status}")
        
        # Store in cache
        CallFlowEngine.Calls.CallRegistry.put_call(call)
        
        # Register call with Bitrix24 using supervised task
        Task.Supervisor.start_child(
          CallFlowEngine.TaskSupervisor,
          fn -> BitrixClient.register_call(call) end
        )
        
        {:ok, call}

      {:error, changeset} ->
        Logger.error("Failed to create call: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  defp answer_call(call, payload) do
    attrs = %{
      status: "answered",
      answered_at: payload.occurred_at
    }

    case call |> Call.changeset(attrs) |> Repo.update() do
      {:ok, updated_call} ->
        Logger.info("Call #{call.call_id} answered")
        
        # Update cache
        CallFlowEngine.Calls.CallRegistry.put_call(updated_call)
        
        {:ok, updated_call}

      {:error, changeset} ->
        Logger.error("Failed to update call: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  defp finish_call(call, payload) do
    attrs = %{
      status: "finished",
      ended_at: payload.occurred_at
    }

    case call |> Call.changeset(attrs) |> Repo.update() do
      {:ok, updated_call} ->
        Logger.info("Call #{call.call_id} finished")
        
        # Remove from cache (call is finished)
        CallFlowEngine.Calls.CallRegistry.delete_call(call.call_id)
        
        # Send final status to Bitrix24 using supervised task
        Task.Supervisor.start_child(
          CallFlowEngine.TaskSupervisor,
          fn -> BitrixClient.finish_call(updated_call) end
        )
        
        {:ok, updated_call}

      {:error, changeset} ->
        Logger.error("Failed to finish call: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  defp update_call_variables(call, payload) do
    # Extract variables from payload and update call if needed
    variables = payload.raw_payload["variable"] || %{}
    
    # Update direction or numbers based on variables
    updates = %{}
    
    updates = if variables["intNum"] do
      Map.put(updates, :direction, "outbound")
    else
      updates
    end
    
    updates = if variables["extNum"] do
      Map.put(updates, :direction, "inbound")
    else
      updates
    end

    if map_size(updates) > 0 do
      case call |> Call.changeset(updates) |> Repo.update() do
        {:ok, updated_call} ->
          Logger.debug("Updated call variables for #{call.call_id}")
          
          # Update cache
          CallFlowEngine.Calls.CallRegistry.put_call(updated_call)
          
          {:ok, updated_call}
        
        {:error, changeset} ->
          Logger.error("Failed to update call variables: #{inspect(changeset.errors)}")
          {:error, changeset}
      end
    else
      {:ok, call}
    end
  end

  @doc """
  Gets a call by call_id.
  """
  def get_call(call_id) do
    Repo.get_by(Call, call_id: call_id)
  end

  @doc """
  Lists calls with optional filters.
  """
  def list_calls(filters \\ %{}) do
    query = from c in Call, order_by: [desc: c.started_at]
    
    query = if status = filters[:status] do
      from c in query, where: c.status == ^status
    else
      query
    end
    
    query = if direction = filters[:direction] do
      from c in query, where: c.direction == ^direction
    else
      query
    end
    
    limit = filters[:limit] || 50
    
    query
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Gets a call with its events.
  """
  def get_call_with_events(call_id) do
    alias CallFlowEngine.Events.CallEvent
    
    case get_call(call_id) do
      nil -> {:error, :not_found}
      call ->
        events = 
          from(e in CallEvent,
            where: e.call_id == ^call_id,
            order_by: [asc: e.occurred_at]
          )
          |> Repo.all()
        
        {:ok, call, events}
    end
  end
end
