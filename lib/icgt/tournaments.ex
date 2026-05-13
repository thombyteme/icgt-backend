defmodule Icgt.Tournaments do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Icgt.AmsterdamTime
  alias Icgt.Repo
  alias Icgt.Tournaments.Match
  alias Icgt.Tournaments.Team
  alias Icgt.Tournaments.TeamContactPerson

  def list_matches do
    Repo.all(from m in Match, order_by: [asc: m.starts_at, asc: m.id])
  end

  def list_teams do
    Repo.all(
      from t in Team,
        left_join: c in assoc(t, :contact_people),
        group_by: t.id,
        order_by: [asc: fragment("lower(?)", t.name)],
        select_merge: %{contact_people_count: count(c.id)}
    )
  end

  def get_team!(id) do
    Team
    |> Repo.get!(id)
    |> Repo.preload(
      contact_people: from(c in TeamContactPerson, order_by: [asc: c.name, asc: c.id])
    )
  end

  def update_team(%Team{} = team, attrs) do
    team
    |> Team.changeset(attrs)
    |> Repo.update()
  end

  def change_team(%Team{} = team, attrs \\ %{}) do
    Team.changeset(team, attrs)
  end

  def create_team_contact_person(%Team{} = team, attrs) do
    %TeamContactPerson{}
    |> TeamContactPerson.changeset(Map.put(attrs, "team_id", team.id))
    |> Repo.insert()
  end

  def update_team_contact_person(%TeamContactPerson{} = contact_person, attrs) do
    contact_person
    |> TeamContactPerson.changeset(attrs)
    |> Repo.update()
  end

  def delete_team_contact_person(%TeamContactPerson{} = contact_person) do
    Repo.delete(contact_person)
  end

  def get_team_contact_person!(%Team{} = team, id) do
    Repo.get_by!(TeamContactPerson, id: id, team_id: team.id)
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
            updated_at: AmsterdamTime.now()
          ]
        ],
        conflict_target: [:source, :unique_key]
      )
    end
  end

  def mark_captains_notified(match_id) do
    now = AmsterdamTime.now()

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
