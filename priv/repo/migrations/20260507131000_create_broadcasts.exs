defmodule Icgt.Repo.Migrations.CreateBroadcasts do
  use Ecto.Migration

  def change do
    create table(:broadcasts) do
      add :kind, :string, null: false
      add :round_starts_at, :utc_datetime, null: false
      add :target_round_starts_at, :utc_datetime, null: false
      add :scheduled_for, :utc_datetime, null: false
      add :status, :string, null: false
      add :text, :text, null: false
      add :audio_file_path, :string
      add :played_at, :utc_datetime
      add :last_error, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:broadcasts, [:kind, :target_round_starts_at, :scheduled_for])
    create index(:broadcasts, [:status, :scheduled_for])
    create index(:broadcasts, [:target_round_starts_at])
  end
end
