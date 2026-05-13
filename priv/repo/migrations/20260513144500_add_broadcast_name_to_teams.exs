defmodule Icgt.Repo.Migrations.AddBroadcastNameToTeams do
  use Ecto.Migration

  def change do
    alter table(:teams) do
      add :broadcast_name, :string
    end
  end
end
