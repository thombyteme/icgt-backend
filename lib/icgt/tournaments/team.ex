defmodule Icgt.Tournaments.Team do
  use Ecto.Schema
  import Ecto.Changeset

  alias Icgt.Tournaments.Match
  alias Icgt.Tournaments.TeamContactPerson

  schema "teams" do
    field :name, :string
    field :broadcast_name, :string
    field :normalized_name, :string
    field :contact_people_count, :integer, virtual: true, default: 0
    has_many :home_matches, Match, foreign_key: :team_a_id
    has_many :away_matches, Match, foreign_key: :team_b_id
    has_many :contact_people, TeamContactPerson

    timestamps(type: :utc_datetime)
  end

  def changeset(team, attrs) do
    team
    |> cast(attrs, [:name, :broadcast_name])
    |> validate_required([:name])
    |> update_change(:name, &String.trim/1)
    |> update_change(:broadcast_name, &normalize_optional_string/1)
    |> validate_length(:name, min: 1)
    |> put_change(:normalized_name, normalize_name(get_field_value(team, attrs, :name)))
    |> unique_constraint(:normalized_name)
  end

  def normalize_name(nil), do: nil

  def normalize_name(name) when is_binary(name) do
    name
    |> String.trim()
    |> String.downcase()
  end

  defp normalize_optional_string(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_optional_string(value), do: value

  defp get_field_value(team, attrs, field) do
    Map.get(attrs, field) || Map.get(attrs, to_string(field)) || Map.get(team, field)
  end
end
