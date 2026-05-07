defmodule Icgt.Repo.Migrations.CreateTeamContactPeople do
  use Ecto.Migration

  def change do
    create table(:team_contact_people) do
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :phone_number, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:team_contact_people, [:team_id])
  end
end
