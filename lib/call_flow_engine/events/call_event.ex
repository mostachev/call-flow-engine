defmodule CallFlowEngine.Events.CallEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          call_id: String.t(),
          event_type: String.t(),
          payload: map(),
          occurred_at: DateTime.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "call_events" do
    field :call_id, :string
    field :event_type, :string
    field :payload, :map
    field :occurred_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(call_event, attrs) do
    call_event
    |> cast(attrs, [:call_id, :event_type, :payload, :occurred_at])
    |> validate_required([:call_id, :event_type, :occurred_at])
  end
end
