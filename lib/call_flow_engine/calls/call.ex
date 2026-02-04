defmodule CallFlowEngine.Calls.Call do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: binary(),
          call_id: String.t(),
          direction: String.t() | nil,
          caller_number: String.t() | nil,
          callee_number: String.t() | nil,
          status: String.t(),
          started_at: DateTime.t() | nil,
          answered_at: DateTime.t() | nil,
          ended_at: DateTime.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "calls" do
    field :call_id, :string
    field :direction, :string
    field :caller_number, :string
    field :callee_number, :string
    field :status, :string
    field :started_at, :utc_datetime
    field :answered_at, :utc_datetime
    field :ended_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(call, attrs) do
    call
    |> cast(attrs, [
      :call_id,
      :direction,
      :caller_number,
      :callee_number,
      :status,
      :started_at,
      :answered_at,
      :ended_at
    ])
    |> validate_required([:call_id, :status])
    |> validate_inclusion(:status, ["ringing", "answered", "finished", "error"])
    |> validate_inclusion(:direction, ["inbound", "outbound", "unknown"])
    |> unique_constraint(:call_id)
  end
end
