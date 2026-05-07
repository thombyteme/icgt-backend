defmodule Icgt.Tournaments.TeamContactPerson do
  use Ecto.Schema

  alias Icgt.Tournaments.Team

  schema "team_contact_people" do
    belongs_to :team, Team
    field :name, :string
    field :phone_number, :string

    timestamps(type: :utc_datetime)
  end
end
