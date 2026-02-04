defmodule CallFlowEngine.Events.EventProcessor do
  @moduledoc """
  GenServer that processes call events, maintains statistics, and coordinates with CallService.
  """

  use GenServer
  require Logger

  alias CallFlowEngine.Events.{CallEvent, CallEventPayload}
  alias CallFlowEngine.Calls.CallService
  alias CallFlowEngine.Repo

  @type state :: %{
          total_events: non_neg_integer(),
          events_per_type: %{String.t() => non_neg_integer()},
          events_per_call: %{String.t() => non_neg_integer()}
        }

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Processes a call event payload asynchronously.
  Returns :ok immediately without blocking the caller.
  """
  @spec process_event(CallEventPayload.t()) :: :ok
  def process_event(%CallEventPayload{} = payload) do
    GenServer.cast(__MODULE__, {:process_event, payload})
  end
  
  @doc """
  Processes a call event payload synchronously (for testing).
  """
  @spec process_event_sync(CallEventPayload.t(), timeout()) :: :ok | {:error, term()}
  def process_event_sync(%CallEventPayload{} = payload, timeout \\ 5_000) do
    GenServer.call(__MODULE__, {:process_event_sync, payload}, timeout)
  end

  @doc """
  Returns current statistics.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # Server Callbacks

  @impl true
  def init(_) do
    Logger.info("EventProcessor started")
    
    initial_state = %{
      total_events: 0,
      events_per_type: %{},
      events_per_call: %{}
    }
    
    {:ok, initial_state}
  end

  @impl true
  def handle_cast({:process_event, payload}, state) do
    new_state = do_process_event(payload, state)
    {:noreply, new_state}
  end
  
  @impl true
  def handle_call({:process_event_sync, payload}, _from, state) do
    new_state = do_process_event(payload, state)
    {:reply, :ok, new_state}
  end
  
  # Shared processing logic
  defp do_process_event(payload, state) do
    try do
      # Emit telemetry event
      start_time = System.monotonic_time()
      
      # 1. Persist event to database
      event_attrs = %{
        call_id: payload.call_id,
        event_type: payload.event_type,
        payload: payload.raw_payload,
        occurred_at: payload.occurred_at
      }

      case %CallEvent{} |> CallEvent.changeset(event_attrs) |> Repo.insert() do
        {:ok, _event} ->
          Logger.debug("Persisted event #{payload.event_type} for call #{payload.call_id}")

        {:error, changeset} ->
          Logger.error("Failed to persist event: #{inspect(changeset.errors)}")
      end

      # 2. Update in-memory statistics
      new_state = update_statistics(state, payload)

      # 3. Delegate business logic to CallService
      CallService.handle_event(payload)
      
      # 4. Emit telemetry
      duration = System.monotonic_time() - start_time
      :telemetry.execute(
        [:call_flow_engine, :event, :processed],
        %{duration: duration},
        %{event_type: payload.event_type, call_id: payload.call_id}
      )

      new_state
    rescue
      e ->
        Logger.error("Error processing event: #{inspect(e)}")
        Logger.error(Exception.format_stacktrace(__STACKTRACE__))
        
        :telemetry.execute(
          [:call_flow_engine, :event, :error],
          %{count: 1},
          %{error: inspect(e), event_type: payload.event_type}
        )
        
        state
    end
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      total_events: state.total_events,
      events_per_type: state.events_per_type,
      events_per_call: state.events_per_call
    }
    
    {:reply, stats, state}
  end
  
  @impl true
  def handle_info(msg, state) do
    Logger.warning("Unexpected message in EventProcessor: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private Functions

  defp update_statistics(state, payload) do
    %{
      total_events: state.total_events + 1,
      events_per_type: increment_map(state.events_per_type, payload.event_type),
      events_per_call: increment_map(state.events_per_call, payload.call_id)
    }
  end

  defp increment_map(map, key) do
    Map.update(map, key, 1, &(&1 + 1))
  end
end
