defmodule CallFlowEngine.Repo.Migrations.CreateCalls do
  use Ecto.Migration

  def change do
    create table(:calls, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :call_id, :string, null: false
      add :direction, :string
      add :caller_number, :string
      add :callee_number, :string
      add :status, :string, null: false
      add :started_at, :utc_datetime
      add :answered_at, :utc_datetime
      add :ended_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:calls, [:call_id])
    create index(:calls, [:status])
    create index(:calls, [:direction])
    create index(:calls, [:started_at])
  end
end
