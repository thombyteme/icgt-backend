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
      add :team_a, :string
      add :team_b, :string
      add :status, :string

      add :raw_data, :map, null: false, default: %{}

      add :captains_notified_at, :utc_datetime
      add :broadcast_started_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:matches, [:source, :unique_key])
    create index(:matches, [:starts_at])
    create index(:matches, [:status])
  end
end
