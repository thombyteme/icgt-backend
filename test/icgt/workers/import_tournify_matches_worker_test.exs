defmodule Icgt.Workers.ImportTournifyMatchesWorkerTest do
  use Icgt.DataCase

  alias Icgt.Broadcasts.Broadcast
  alias Icgt.Repo
  alias Icgt.Tournaments.Match
  alias Icgt.Workers.ImportTournifyMatchesWorker

  setup do
    Application.put_env(:icgt, :tournify_importer, Icgt.FakeTournifyImporter)

    on_exit(fn ->
      Application.delete_env(:icgt, :tournify_importer)
    end)

    :ok
  end

  test "materializes broadcasts after a successful import" do
    insert_match!(~U[2026-05-23 10:00:00Z])

    assert :ok = ImportTournifyMatchesWorker.perform(%Oban.Job{})
    assert Repo.aggregate(Broadcast, :count) == 2
  end

  defp insert_match!(starts_at) do
    %Match{}
    |> Match.changeset(%{
      source: "test",
      external_id: "test",
      unique_key: "test",
      starts_at: starts_at,
      starts_at_local: DateTime.to_naive(starts_at),
      timezone: "Europe/Amsterdam",
      field: "1",
      date_iso: DateTime.to_date(starts_at),
      poule: "Klasse 1",
      referee: "Scheidsrechter",
      team_a_name: "Team A",
      team_b_name: "Team B",
      status: "scheduled",
      raw_data: %{}
    })
    |> Repo.insert!()
  end
end
