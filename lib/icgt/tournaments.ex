defmodule Icgt.Tournaments do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Icgt.Repo
  alias Icgt.Tournaments.Match
  alias Icgt.Tournaments.Team

  def list_matches do
    Repo.all(from m in Match, order_by: [asc: m.starts_at, asc: m.id])
  end

  def list_matches_starting_between(start_at, end_at) do
    Repo.all(
      from m in Match,
        where:
          not is_nil(m.starts_at) and
            is_nil(m.captains_notified_at) and
            m.starts_at >= ^start_at and
            m.starts_at <= ^end_at,
        preload: [team_a: :contact_people, team_b: :contact_people],
        order_by: [asc: m.starts_at, asc: m.id]
    )
  end

  def upsert_match(attrs) do
    with {:ok, team_a_id} <- ensure_team_id(Map.get(attrs, :team_a_name)),
         {:ok, team_b_id} <- ensure_team_id(Map.get(attrs, :team_b_name)) do
      attrs =
        attrs
        |> Map.put(:team_a_id, team_a_id)
        |> Map.put(:team_b_id, team_b_id)

      changeset = Match.changeset(%Match{}, attrs)

      Repo.insert(changeset,
        on_conflict: [
          set: [
            external_id: Map.get(attrs, :external_id),
            starts_at: Map.get(attrs, :starts_at),
            starts_at_local: Map.get(attrs, :starts_at_local),
            timezone: Map.get(attrs, :timezone),
            field: Map.get(attrs, :field),
            date_iso: Map.get(attrs, :date_iso),
            poule: Map.get(attrs, :poule),
            referee: Map.get(attrs, :referee),
            team_a_name: Map.get(attrs, :team_a_name),
            team_b_name: Map.get(attrs, :team_b_name),
            team_a_id: Map.get(attrs, :team_a_id),
            team_b_id: Map.get(attrs, :team_b_id),
            status: Map.get(attrs, :status),
            raw_data: Map.get(attrs, :raw_data),
            updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
          ]
        ],
        conflict_target: [:source, :unique_key]
      )
    end
  end

  def mark_captains_notified(match_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {updated, _} =
      Repo.update_all(
        from(m in Match, where: m.id == ^match_id and is_nil(m.captains_notified_at)),
        set: [captains_notified_at: now, updated_at: now]
      )

    {:ok, updated}
  end

  defp ensure_team_id(nil), do: {:ok, nil}
  defp ensure_team_id(""), do: {:ok, nil}

  defp ensure_team_id(name) when is_binary(name) do
    normalized_name = Team.normalize_name(name)

    case Repo.get_by(Team, normalized_name: normalized_name) do
      %Team{id: id} ->
        {:ok, id}

      nil ->
        create_team(name, normalized_name)
    end
  end

  defp create_team(name, normalized_name) do
    case %Team{} |> Team.changeset(%{name: name}) |> Repo.insert() do
      {:ok, %Team{id: id}} ->
        {:ok, id}

      {:error, %Ecto.Changeset{errors: [normalized_name: {"has already been taken", _}]}} ->
        case Repo.get_by(Team, normalized_name: normalized_name) do
          %Team{id: id} -> {:ok, id}
          nil -> {:error, :team_creation_race_condition}
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end
end
