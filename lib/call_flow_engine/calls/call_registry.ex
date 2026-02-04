defmodule CallFlowEngine.Calls.CallRegistry do
  @moduledoc """
  ETS-based cache for active calls to reduce database queries.
  Provides fast lookup for call_id -> call mapping.
  """

  use GenServer
  require Logger

  @table_name :call_registry
  @cleanup_interval :timer.minutes(5)

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Gets a call from cache or database.
  """
  @spec get_call(String.t()) :: CallFlowEngine.Calls.Call.t() | nil
  def get_call(call_id) do
    case :ets.lookup(@table_name, call_id) do
      [{^call_id, call, _timestamp}] -> 
        call
      [] -> 
        # Not in cache, fetch from DB
        case CallFlowEngine.Repo.get_by(CallFlowEngine.Calls.Call, call_id: call_id) do
          nil -> nil
          call -> 
            put_call(call)
            call
        end
    end
  end

  @doc """
  Puts a call into cache.
  """
  @spec put_call(CallFlowEngine.Calls.Call.t()) :: :ok
  def put_call(%CallFlowEngine.Calls.Call{} = call) do
    :ets.insert(@table_name, {call.call_id, call, System.monotonic_time(:second)})
    :ok
  end

  @doc """
  Removes a call from cache.
  """
  @spec delete_call(String.t()) :: :ok
  def delete_call(call_id) do
    :ets.delete(@table_name, call_id)
    :ok
  end

  @doc """
  Clears entire cache.
  """
  @spec clear :: :ok
  def clear do
    :ets.delete_all_objects(@table_name)
    :ok
  end

  # Server Callbacks

  @impl true
  def init(_) do
    Logger.info("Starting CallRegistry with ETS cache")
    
    # Create ETS table
    :ets.new(@table_name, [:named_table, :public, :set, read_concurrency: true])
    
    # Schedule periodic cleanup
    schedule_cleanup()
    
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_old_entries()
    schedule_cleanup()
    {:noreply, state}
  end

  # Private Functions

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp cleanup_old_entries do
    now = System.monotonic_time(:second)
    # Remove entries older than 1 hour
    cutoff = now - 3600
    
    count = :ets.select_delete(@table_name, [
      {{:_, :_, :"$1"}, [{:<, :"$1", cutoff}], [true]}
    ])
    
    if count > 0 do
      Logger.debug("Cleaned up #{count} old call entries from cache")
    end
  end
end
