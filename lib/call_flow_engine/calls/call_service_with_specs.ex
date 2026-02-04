defmodule CallFlowEngine.Calls.CallServiceWithSpecs do
  @moduledoc """
  Type-specified version of CallService showing proper Elixir practices.
  
  This module demonstrates:
  - @spec for all public functions
  - @type for complex types
  - Proper error handling patterns
  - Documentation with examples
  """

  require Logger
  
  alias CallFlowEngine.Calls.Call
  alias CallFlowEngine.Events.CallEventPayload
  alias CallFlowEngine.Integrations.BitrixClient
  alias CallFlowEngine.Repo

  import Ecto.Query

  @type call_filters :: %{
    optional(:status) => String.t(),
    optional(:direction) => String.t(),
    optional(:limit) => pos_integer()
  }

  @type call_result :: {:ok, Call.t()} | {:error, Ecto.Changeset.t() | atom()}

  # Public API with specs

  @doc """
  Handles a call event and updates call state accordingly.
  
  ## Examples
  
      iex> payload = %CallEventPayload{event_type: "stasis_start", call_id: "123", ...}
      iex> CallService.handle_event(payload)
      {:ok, %Call{}}
  """
  @spec handle_event(CallEventPayload.t()) :: call_result() | :ok
  def handle_event(%CallEventPayload{} = payload) do
    CallFlowEngine.Calls.CallService.handle_event(payload)
  end

  @doc """
  Gets a call by call_id.
  
  ## Examples
  
      iex> CallService.get_call("call-123")
      %Call{}
      
      iex> CallService.get_call("nonexistent")
      nil
  """
  @spec get_call(String.t()) :: Call.t() | nil
  def get_call(call_id) when is_binary(call_id) do
    CallFlowEngine.Calls.CallService.get_call(call_id)
  end

  @doc """
  Lists calls with optional filters.
  
  ## Examples
  
      iex> CallService.list_calls(%{status: "finished", limit: 10})
      [%Call{}, ...]
      
      iex> CallService.list_calls(%{direction: "inbound"})
      [%Call{}, ...]
  """
  @spec list_calls(call_filters()) :: [Call.t()]
  def list_calls(filters \\ %{}) when is_map(filters) do
    CallFlowEngine.Calls.CallService.list_calls(filters)
  end

  @doc """
  Gets a call with its events.
  
  ## Examples
  
      iex> CallService.get_call_with_events("call-123")
      {:ok, %Call{}, [%CallEvent{}, ...]}
      
      iex> CallService.get_call_with_events("nonexistent")
      {:error, :not_found}
  """
  @spec get_call_with_events(String.t()) :: 
    {:ok, Call.t(), [CallFlowEngine.Events.CallEvent.t()]} | 
    {:error, :not_found}
  def get_call_with_events(call_id) when is_binary(call_id) do
    CallFlowEngine.Calls.CallService.get_call_with_events(call_id)
  end
end
