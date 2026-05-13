defmodule Icgt.Repo.Migrations.CreateMatchNotifications do
  use Ecto.Migration

  def change do
    create table(:match_notifications) do
      add :match_id, references(:matches, on_delete: :delete_all), null: false

      add :team_contact_person_id, references(:team_contact_people, on_delete: :delete_all),
        null: false

      add :kind, :string, null: false
      add :status, :string, null: false
      add :provider_message_id, :string
      add :sent_at, :utc_datetime
      add :last_error, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:match_notifications, [:match_id, :team_contact_person_id, :kind])
    create index(:match_notifications, [:match_id, :kind, :status])
  end
end
