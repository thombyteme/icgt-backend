defmodule Icgt.Tournaments.Match do
  use Ecto.Schema
  import Ecto.Changeset

  schema "matches" do
    field :source, :string
    field :external_id, :string
    field :unique_key, :string

    field :starts_at, :utc_datetime
    field :starts_at_local, :naive_datetime
    field :timezone, :string, default: "Europe/Amsterdam"

    field :field, :string
    field :team_a, :string
    field :team_b, :string
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
      :team_a,
      :team_b,
      :status,
      :raw_data,
      :captains_notified_at,
      :broadcast_started_at
    ])
    |> validate_required([:source, :unique_key])
    |> unique_constraint([:source, :unique_key])
  end
end
