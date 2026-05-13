defmodule Icgt.Tournaments.TeamContactPerson do
  use Ecto.Schema
  import Ecto.Changeset

  alias Icgt.Tournaments.Team

  schema "team_contact_people" do
    belongs_to :team, Team
    field :name, :string
    field :phone_number, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(contact_person, attrs) do
    contact_person
    |> cast(attrs, [:team_id, :name, :phone_number])
    |> validate_required([:team_id, :name, :phone_number])
    |> update_change(:name, &String.trim/1)
    |> update_change(:phone_number, &String.trim/1)
    |> validate_length(:name, min: 1)
    |> validate_length(:phone_number, min: 1)
    |> foreign_key_constraint(:team_id)
  end
end
