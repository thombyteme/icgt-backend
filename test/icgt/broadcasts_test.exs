defmodule Icgt.BroadcastsTest do
  use Icgt.DataCase

  alias Icgt.Broadcasts
  alias Icgt.Broadcasts.Broadcast
  alias Icgt.Repo
  alias Icgt.Tournaments.Match
  alias Icgt.Tournaments.Team

  setup do
    audio_dir = Path.join(System.tmp_dir!(), "icgt-broadcasts-test-#{System.unique_integer()}")

    Application.put_env(:icgt, :broadcast_tts_provider, Icgt.FakeTtsProvider)
    Application.put_env(:icgt, :broadcast_audio_dir, audio_dir)

    on_exit(fn ->
      Application.delete_env(:icgt, :broadcast_tts_provider)
      Application.delete_env(:icgt, :broadcast_audio_dir)
      File.rm_rf(audio_dir)
    end)

    :ok
  end

  test "materializes all broadcasts for a full day schedule" do
    first_round = ~U[2026-05-23 10:00:00Z]
    next_round = ~U[2026-05-23 10:30:00Z]
    insert_match!(first_round, "1")
    insert_match!(next_round, "2")

    assert results = Broadcasts.materialize_all_broadcasts()
    assert length(results) == 5
    assert Enum.all?(results, &match?({:ok, %Broadcast{}}, &1))

    broadcasts = Broadcasts.list_player_broadcasts()

    assert Enum.map(broadcasts, &{&1.kind, &1.target_round_starts_at, &1.scheduled_for}) == [
             {"round_announcement", first_round, ~U[2026-05-23 09:45:00Z]},
             {"round_announcement", next_round, ~U[2026-05-23 10:15:00Z]},
             {"referee_whistle", first_round, ~U[2026-05-23 10:25:00Z]},
             {"round_announcement", next_round, ~U[2026-05-23 10:25:00Z]},
             {"referee_whistle", next_round, ~U[2026-05-23 10:55:00Z]}
           ]

    assert Enum.all?(broadcasts, &(&1.status == "pending"))
    assert Enum.all?(broadcasts, &is_nil(&1.audio_file_path))
  end

  test "materializes each day independently" do
    day_one_round = ~U[2026-05-23 18:30:00Z]
    day_two_round = ~U[2026-05-24 09:30:00Z]
    insert_match!(day_one_round, "1", %{date_iso: ~D[2026-05-23]})
    insert_match!(day_two_round, "1", %{date_iso: ~D[2026-05-24]})

    assert results = Broadcasts.materialize_all_broadcasts()
    assert length(results) == 4

    announcements = Repo.all(from b in Broadcast, where: b.kind == "round_announcement")

    assert Enum.map(announcements, & &1.target_round_starts_at) |> Enum.sort() == [
             day_one_round,
             day_two_round
           ]
  end

  test "materialization is idempotent" do
    round = ~U[2026-05-23 10:00:00Z]
    insert_match!(round, "1")

    assert results = Broadcasts.materialize_all_broadcasts()
    assert length(results) == 2
    assert Enum.all?(results, &match?({:ok, %Broadcast{}}, &1))

    assert results = Broadcasts.materialize_all_broadcasts()
    assert length(results) == 2
    assert Enum.all?(results, &match?({:ok, %Broadcast{}}, &1))

    assert Repo.aggregate(Broadcast, :count) == 2
  end

  test "orders whistle before announcement when they are scheduled for the same time" do
    first_round = ~U[2026-05-23 10:00:00Z]
    next_round = ~U[2026-05-23 10:30:00Z]
    insert_match!(first_round, "1")
    insert_match!(next_round, "2")

    assert [
             {:ok, %Broadcast{kind: "round_announcement"}},
             {:ok, %Broadcast{kind: "round_announcement"}},
             {:ok, %Broadcast{kind: "referee_whistle"}},
             {:ok, %Broadcast{kind: "round_announcement"}},
             {:ok, %Broadcast{kind: "referee_whistle"}}
           ] =
             Broadcasts.materialize_all_broadcasts()

    scheduled_together =
      Broadcasts.list_player_broadcasts()
      |> Enum.filter(&(&1.scheduled_for == ~U[2026-05-23 10:25:00Z]))

    assert Enum.map(scheduled_together, & &1.kind) == [
             "referee_whistle",
             "round_announcement"
           ]
  end

  test "announces the next round fifteen minutes before that round starts" do
    current_round = ~U[2026-05-23 18:30:00Z]
    next_round = ~U[2026-05-23 19:00:00Z]
    insert_match!(current_round, "1")
    insert_match!(next_round, "2")

    Broadcasts.materialize_all_broadcasts()

    next_round_early_announcement =
      Repo.one!(
        from b in Broadcast,
          where:
            b.kind == "round_announcement" and
              b.round_starts_at == ^current_round and
              b.target_round_starts_at == ^next_round and
              b.scheduled_for != ^DateTime.add(current_round, 25 * 60, :second)
      )

    assert next_round_early_announcement.scheduled_for == ~U[2026-05-23 18:45:00Z]
  end

  test "changed text resets a non-played broadcast to pending" do
    round = ~U[2026-05-23 10:00:00Z]
    match = insert_match!(round, "1", %{team_a_name: "Old Team"})

    Broadcasts.materialize_all_broadcasts()

    broadcast =
      Repo.one!(
        from b in Broadcast,
          where: b.kind == "round_announcement" and b.target_round_starts_at == ^round
      )

    broadcast
    |> Broadcast.changeset(%{
      status: "generated",
      audio_file_path: Path.join(Broadcasts.broadcast_audio_dir(), "old.mp3")
    })
    |> Repo.update!()

    match
    |> Match.changeset(%{team_a_name: "New Team"})
    |> Repo.update!()

    Broadcasts.materialize_all_broadcasts()

    updated = Repo.get!(Broadcast, broadcast.id)
    assert updated.status == "pending"
    assert is_nil(updated.audio_file_path)
    assert updated.text =~ "New Team"
  end

  test "materialized broadcast text uses team broadcast names" do
    round = ~U[2026-05-23 10:00:00Z]

    team_a = insert_team!("Saenden zat. 2", "Saenden zaterdag 2")
    team_b = insert_team!("ADO'20 zat. 7", "ADO'20 zaterdag 7")

    insert_match!(round, "1", %{
      team_a_name: "Saenden zat. 2",
      team_b_name: "ADO'20 zat. 7",
      team_a_id: team_a.id,
      team_b_id: team_b.id
    })

    Broadcasts.materialize_all_broadcasts()

    broadcast =
      Repo.one!(
        from b in Broadcast,
          where: b.kind == "round_announcement" and b.target_round_starts_at == ^round
      )

    assert broadcast.text =~ "Saenden zaterdag 2 tegen ADO'20 zaterdag 7"
  end

  test "changed text does not update a played broadcast" do
    round = ~U[2026-05-23 10:00:00Z]
    match = insert_match!(round, "1", %{team_a_name: "Old Team"})

    Broadcasts.materialize_all_broadcasts()

    broadcast =
      Repo.one!(
        from b in Broadcast,
          where: b.kind == "round_announcement" and b.target_round_starts_at == ^round
      )

    broadcast
    |> Broadcast.changeset(%{status: "played", played_at: ~U[2026-05-23 09:50:00Z]})
    |> Repo.update!()

    match
    |> Match.changeset(%{team_a_name: "New Team"})
    |> Repo.update!()

    Broadcasts.materialize_all_broadcasts()

    updated = Repo.get!(Broadcast, broadcast.id)
    assert updated.status == "played"
    assert updated.text =~ "Old Team"
  end

  test "lists only due unplayed broadcasts as playable" do
    due = insert_broadcast!(%{scheduled_for: ~U[2026-05-23 10:00:00Z]})

    insert_broadcast!(%{
      scheduled_for: ~U[2026-05-23 10:00:01Z],
      target_round_starts_at: ~U[2026-05-23 10:00:01Z]
    })

    insert_broadcast!(%{
      scheduled_for: ~U[2026-05-23 09:59:59Z],
      target_round_starts_at: ~U[2026-05-23 09:59:59Z],
      status: "played",
      played_at: ~U[2026-05-23 10:00:00Z]
    })

    assert Broadcasts.list_playable_broadcasts(~U[2026-05-23 10:00:00Z]) == [due]
  end

  test "generates round announcement audio without saving a file path" do
    broadcast = insert_broadcast!(%{text: "Omroep tekst"})

    assert {:binary, "fake mp3"} = Broadcasts.audio_for_broadcast(broadcast)
    assert Repo.get!(Broadcast, broadcast.id).status == "pending"
    assert is_nil(Repo.get!(Broadcast, broadcast.id).audio_file_path)
  end

  test "generates referee whistle audio once and reuses the same file" do
    broadcast =
      insert_broadcast!(%{
        kind: "referee_whistle",
        text: "Scheidsrechters! U mag affluiten!"
      })

    assert {:file, path} = Broadcasts.audio_for_broadcast(broadcast)
    assert File.read!(path) == "fake mp3"

    File.write!(path, "cached mp3")

    assert {:file, ^path} = Broadcasts.audio_for_broadcast(broadcast)
    assert File.read!(path) == "cached mp3"
  end

  test "marks broadcast failed when on-demand TTS fails" do
    broadcast =
      insert_broadcast!(%{
        scheduled_for: ~U[2026-05-23 10:00:00Z],
        text: "fail"
      })

    assert {:error, :fake_tts_failure} = Broadcasts.audio_for_broadcast(broadcast)

    updated = Repo.get!(Broadcast, broadcast.id)
    assert updated.status == "failed"
    assert updated.last_error =~ "fake_tts_failure"
  end

  defp insert_match!(starts_at, field, attrs \\ %{}) do
    defaults = %{
      source: "test",
      external_id: "test-#{starts_at}-#{field}",
      unique_key: "test-#{starts_at}-#{field}",
      starts_at: starts_at,
      starts_at_local: DateTime.to_naive(starts_at),
      timezone: "Europe/Amsterdam",
      field: field,
      date_iso: DateTime.to_date(starts_at),
      poule: "Klasse 1",
      referee: "Scheidsrechter",
      team_a_name: "Team A #{field}",
      team_b_name: "Team B #{field}",
      status: "scheduled",
      raw_data: %{}
    }

    %Match{}
    |> Match.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  defp insert_team!(name, broadcast_name) do
    %Team{}
    |> Team.changeset(%{name: name, broadcast_name: broadcast_name})
    |> Repo.insert!()
  end

  defp insert_broadcast!(attrs) do
    defaults = %{
      kind: "round_announcement",
      round_starts_at: ~U[2026-05-23 10:00:00Z],
      target_round_starts_at: ~U[2026-05-23 10:00:00Z],
      scheduled_for: ~U[2026-05-23 10:00:00Z],
      status: "pending",
      text: "Omroep tekst"
    }

    %Broadcast{}
    |> Broadcast.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end
end
