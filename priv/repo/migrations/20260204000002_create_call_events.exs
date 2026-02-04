defmodule CallFlowEngine.Repo.Migrations.CreateCallEvents do
  use Ecto.Migration

  def change do
    create table(:call_events) do
      add :call_id, :string, null: false
      add :event_type, :string, null: false
      add :payload, :map
      add :occurred_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:call_events, [:call_id])
    create index(:call_events, [:event_type])
    create index(:call_events, [:occurred_at])
  end
end
