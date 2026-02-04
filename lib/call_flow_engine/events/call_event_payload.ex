defmodule CallFlowEngine.Events.CallEventPayload do
  @moduledoc """
  Normalized structure for call events from ARI or test API.
  """

  @type t :: %__MODULE__{
          call_id: String.t(),
          event_type: String.t(),
          direction: atom(),
          channel: String.t() | nil,
          caller_number: String.t() | nil,
          callee_number: String.t() | nil,
          state: String.t() | nil,
          raw_payload: map(),
          occurred_at: DateTime.t()
        }

  defstruct [
    :call_id,
    :event_type,
    :direction,
    :channel,
    :caller_number,
    :callee_number,
    :state,
    :raw_payload,
    :occurred_at
  ]

  @doc """
  Creates a new CallEventPayload struct.
  """
  def new(attrs) do
    struct(__MODULE__, attrs)
  end
end
