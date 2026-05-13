defmodule Icgt.Broadcasts do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Icgt.Broadcasts.Broadcast
  alias Icgt.Broadcasts.TextGenerator
  alias Icgt.AmsterdamTime
  alias Icgt.Repo
  alias Icgt.Tournaments.Match

  @match_duration_minutes 25
  @pre_end_announcement_offset_minutes 10
  @first_round_announcement_offset_minutes -15
  @topic "broadcasts"

  def topic, do: @topic

  def get_broadcast!(id), do: Repo.get!(Broadcast, id)

  def list_player_broadcasts(limit \\ 25) do
    Repo.all(
      from b in Broadcast,
        where: b.status in ["pending", "generated", "played", "failed"],
        order_by: ^broadcast_order_by(),
        limit: ^limit
    )
  end

  def list_playable_broadcasts do
    list_playable_broadcasts(AmsterdamTime.now())
  end

  def list_playable_broadcasts(now) do
    now = AmsterdamTime.as_stored_datetime(now)

    Repo.all(
      from b in Broadcast,
        where:
          b.status in ["pending", "generated"] and is_nil(b.played_at) and
            b.scheduled_for <= ^now,
        order_by: ^broadcast_order_by()
    )
  end

  def materialize_all_broadcasts do
    all_specs()
    |> Enum.map(&materialize_spec/1)
  end

  def mark_played(id) do
    now = AmsterdamTime.now()

    id
    |> get_broadcast!()
    |> Broadcast.changeset(%{status: "played", played_at: now})
    |> Repo.update()
    |> tap(fn
      {:ok, broadcast} -> broadcast_change(broadcast)
      _ -> :ok
    end)
  end

  def broadcast_audio_dir do
    Application.get_env(:icgt, :broadcast_audio_dir) ||
      Path.expand("priv/static/broadcasts", File.cwd!())
  end

  def audio_for_broadcast(%Broadcast{kind: "referee_whistle"}) do
    with {:ok, path} <- ensure_referee_whistle_audio() do
      {:file, path}
    end
  end

  def audio_for_broadcast(%Broadcast{} = broadcast) do
    tts_provider = Application.get_env(:icgt, :broadcast_tts_provider, Icgt.Broadcasts.ElevenLabs)

    case tts_provider.generate_speech(broadcast.text) do
      {:ok, audio} when is_binary(audio) ->
        {:binary, audio}

      {:error, reason} ->
        _ = mark_failed(broadcast, reason)
        {:error, reason}
    end
  end

  def ensure_referee_whistle_audio do
    path = referee_whistle_audio_path()

    if File.exists?(path) do
      {:ok, path}
    else
      tts_provider =
        Application.get_env(:icgt, :broadcast_tts_provider, Icgt.Broadcasts.ElevenLabs)

      with {:ok, audio} <- tts_provider.generate_speech(TextGenerator.referee_whistle()),
           :ok <- File.mkdir_p(Path.dirname(path)),
           :ok <- File.write(path, audio) do
        {:ok, path}
      end
    end
  end

  def referee_whistle_audio_path do
    Path.join(broadcast_audio_dir(), "referee-whistle.mp3")
  end

  defp materialize_spec(spec) do
    attrs =
      spec
      |> Map.take([:kind, :round_starts_at, :target_round_starts_at, :scheduled_for, :text])
      |> Map.put(:status, "pending")

    case existing_broadcast(attrs) do
      nil -> insert_pending(attrs)
      %Broadcast{status: "played"} = broadcast -> {:ok, broadcast}
      %Broadcast{} = broadcast -> maybe_update_materialized_broadcast(broadcast, attrs)
    end
  end

  defp insert_pending(attrs) do
    %Broadcast{}
    |> Broadcast.changeset(attrs)
    |> Repo.insert()
    |> tap(fn
      {:ok, broadcast} -> broadcast_change(broadcast)
      _ -> :ok
    end)
  end

  defp maybe_update_materialized_broadcast(broadcast, attrs) do
    current_text = broadcast.text || ""
    next_text = attrs.text || ""

    if current_text == next_text and broadcast.round_starts_at == attrs.round_starts_at do
      {:ok, broadcast}
    else
      broadcast
      |> Broadcast.changeset(%{
        round_starts_at: attrs.round_starts_at,
        text: next_text,
        status: "pending",
        audio_file_path: nil,
        last_error: nil
      })
      |> Repo.update()
      |> tap(fn
        {:ok, updated} -> broadcast_change(updated)
        _ -> :ok
      end)
    end
  end

  defp existing_broadcast(attrs) do
    Repo.get_by(Broadcast,
      kind: attrs.kind,
      target_round_starts_at: attrs.target_round_starts_at,
      scheduled_for: attrs.scheduled_for
    )
  end

  def mark_failed(broadcast, reason) do
    broadcast
    |> Broadcast.changeset(%{
      status: "failed",
      last_error: reason |> inspect() |> String.slice(0, 2000)
    })
    |> Repo.update()
    |> tap(fn
      {:ok, updated} -> broadcast_change(updated)
      _ -> :ok
    end)
  end

  defp all_specs do
    rounds()
    |> Enum.group_by(& &1.date_iso)
    |> Enum.sort_by(fn {date, _rounds} -> date || ~D[9999-12-31] end)
    |> Enum.flat_map(fn {_date, rounds_for_day} ->
      rounds_for_day
      |> Enum.sort_by(& &1.starts_at)
      |> day_specs()
    end)
    |> Enum.sort_by(&broadcast_sort_key/1)
  end

  defp broadcast_order_by do
    [
      asc: dynamic([b], b.scheduled_for),
      asc: dynamic([b], fragment("CASE WHEN ? = 'referee_whistle' THEN 0 ELSE 1 END", b.kind)),
      asc: dynamic([b], b.id)
    ]
  end

  defp broadcast_sort_key(broadcast) do
    {
      DateTime.to_unix(broadcast.scheduled_for),
      kind_priority(broadcast.kind),
      DateTime.to_unix(broadcast.target_round_starts_at)
    }
  end

  defp kind_priority("referee_whistle"), do: 0
  defp kind_priority(_kind), do: 1

  defp rounds do
    Repo.all(
      from m in Match,
        where: not is_nil(m.starts_at),
        group_by: [m.starts_at],
        select: %{starts_at: m.starts_at, date_iso: min(m.date_iso)},
        order_by: [asc: min(m.date_iso), asc: m.starts_at]
    )
  end

  defp day_specs(rounds) do
    rounds
    |> Enum.with_index()
    |> Enum.flat_map(fn {round, index} ->
      next_round = Enum.at(rounds, index + 1)

      []
      |> maybe_add_first_round_announcement(round, index)
      |> maybe_add_pre_end_announcement(round, next_round)
      |> maybe_add_whistle(round)
      |> maybe_add_post_whistle_announcement(round, next_round)
    end)
  end

  defp maybe_add_first_round_announcement(specs, round, 0) do
    scheduled_for = add_minutes(round.starts_at, @first_round_announcement_offset_minutes)
    [round_announcement_spec(round.starts_at, round.starts_at, scheduled_for) | specs]
  end

  defp maybe_add_first_round_announcement(specs, _round, _index), do: specs

  defp maybe_add_pre_end_announcement(specs, _round, nil), do: specs

  defp maybe_add_pre_end_announcement(specs, round, next_round) do
    scheduled_for = add_minutes(round.starts_at, @pre_end_announcement_offset_minutes)

    [
      round_announcement_spec(round.starts_at, next_round.starts_at, scheduled_for)
      | specs
    ]
  end

  defp maybe_add_whistle(specs, round) do
    scheduled_for = add_minutes(round.starts_at, @match_duration_minutes)

    [
      %{
        kind: "referee_whistle",
        round_starts_at: round.starts_at,
        target_round_starts_at: round.starts_at,
        scheduled_for: scheduled_for,
        text: TextGenerator.referee_whistle()
      }
      | specs
    ]
  end

  defp maybe_add_post_whistle_announcement(specs, _round, nil), do: specs

  defp maybe_add_post_whistle_announcement(specs, round, next_round) do
    scheduled_for = add_minutes(round.starts_at, @match_duration_minutes)

    [
      round_announcement_spec(round.starts_at, next_round.starts_at, scheduled_for)
      | specs
    ]
  end

  defp round_announcement_spec(round_starts_at, target_round_starts_at, scheduled_for) do
    %{
      kind: "round_announcement",
      round_starts_at: round_starts_at,
      target_round_starts_at: target_round_starts_at,
      scheduled_for: scheduled_for,
      text:
        TextGenerator.round_announcement(
          target_round_starts_at,
          matches_for_round(target_round_starts_at)
        )
    }
  end

  defp matches_for_round(starts_at) do
    Repo.all(
      from m in Match,
        where: m.starts_at == ^starts_at,
        preload: [:team_a, :team_b],
        order_by: [asc: m.field, asc: m.id]
    )
  end

  defp add_minutes(datetime, minutes), do: DateTime.add(datetime, minutes * 60, :second)

  defp broadcast_change(broadcast) do
    Phoenix.PubSub.broadcast(Icgt.PubSub, @topic, {:broadcast_changed, broadcast})
  end
end
