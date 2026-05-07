defmodule Icgt.Tournaments.Match do
  use Ecto.Schema
  import Ecto.Changeset

  alias Icgt.Tournaments.Team

  schema "matches" do
    field :source, :string
    field :external_id, :string
    field :unique_key, :string

    field :starts_at, :utc_datetime
    field :starts_at_local, :naive_datetime
    field :timezone, :string, default: "Europe/Amsterdam"

    field :field, :string
    field :date_iso, :date
    field :poule, :string
    field :referee, :string
    field :team_a_name, :string
    field :team_b_name, :string
    belongs_to :team_a, Team
    belongs_to :team_b, Team
    field :status, :string

    field :raw_data, :map, default: %{}

    field :captains_notified_at, :utc_datetime
    field :broadcast_started_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(match, attrs) do
    match
    |> cast(attrs, [
      :source,
      :external_id,
      :unique_key,
      :starts_at,
      :starts_at_local,
      :timezone,
      :field,
      :date_iso,
      :poule,
      :referee,
      :team_a_name,
      :team_b_name,
      :team_a_id,
      :team_b_id,
      :status,
      :raw_data,
      :captains_notified_at,
      :broadcast_started_at
    ])
    |> validate_required([:source, :unique_key])
    |> unique_constraint([:source, :unique_key])
  end
end
