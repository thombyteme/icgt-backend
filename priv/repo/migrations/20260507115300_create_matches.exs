defmodule Icgt.Repo.Migrations.CreateMatches do
  use Ecto.Migration

  def change do
    create table(:matches) do
      add :source, :string, null: false
      add :external_id, :string
      add :unique_key, :string, null: false

      add :starts_at, :utc_datetime
      add :starts_at_local, :naive_datetime
      add :timezone, :string, default: "Europe/Amsterdam"

      add :field, :string
      add :date_iso, :date
      add :poule, :string
      add :referee, :string
      add :team_a_name, :string
      add :team_b_name, :string
      add :team_a_id, :bigint
      add :team_b_id, :bigint
      add :status, :string

      add :raw_data, :map, null: false, default: %{}

      add :captains_notified_at, :utc_datetime
      add :broadcast_started_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:matches, [:source, :unique_key])
    create index(:matches, [:starts_at])
    create index(:matches, [:status])
    create index(:matches, [:team_a_id])
    create index(:matches, [:team_b_id])
  end
end
