defmodule IcgtWeb.BroadcastPlayerTest do
  use IcgtWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Icgt.Broadcasts
  alias Icgt.Broadcasts.Broadcast
  alias Icgt.Repo

  setup do
    audio_dir =
      Path.join(System.tmp_dir!(), "icgt-audio-controller-test-#{System.unique_integer()}")

    File.mkdir_p!(audio_dir)

    Application.put_env(:icgt, :broadcast_audio_dir, audio_dir)
    Application.put_env(:icgt, :broadcast_tts_provider, Icgt.FakeTtsProvider)

    on_exit(fn ->
      Application.delete_env(:icgt, :broadcast_audio_dir)
      Application.delete_env(:icgt, :broadcast_tts_provider)
      File.rm_rf(audio_dir)
    end)

    {:ok, audio_dir: audio_dir}
  end

  test "player route renders", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/broadcasts/player")

    assert html =~ "Broadcast player"
    assert html =~ "Start audio"
  end

  test "player shows scheduled day and time", %{conn: conn} do
    insert_broadcast!(%{status: "pending"})

    {:ok, _view, html} = live(conn, ~p"/broadcasts/player")

    assert html =~ "Zaterdag 23-05-2026 09:45"
  end

  test "player shows whistle before announcement at the same scheduled time", %{conn: conn} do
    insert_broadcast!(%{
      kind: "round_announcement",
      target_round_starts_at: ~U[2026-05-23 10:30:00Z],
      text: "Wedstrijd aankondiging"
    })

    insert_broadcast!(%{
      kind: "referee_whistle",
      target_round_starts_at: ~U[2026-05-23 10:00:00Z],
      text: "Scheidsrechters! U mag affluiten!"
    })

    {:ok, _view, html} = live(conn, ~p"/broadcasts/player")

    assert :binary.match(html, "Affluiten") < :binary.match(html, "Wedstrijden")
  end

  test "audio endpoint generates round announcement audio on demand", %{conn: conn} do
    broadcast = insert_broadcast!(%{text: "Omroep tekst"})

    conn = get(conn, ~p"/broadcasts/#{broadcast.id}/audio")

    assert response(conn, 200) == "fake mp3"
    assert [content_type] = get_resp_header(conn, "content-type")
    assert content_type =~ "audio/mpeg"

    updated = Broadcasts.get_broadcast!(broadcast.id)
    assert updated.status == "pending"
    assert is_nil(updated.audio_file_path)
  end

  test "audio endpoint serves cached referee whistle audio", %{conn: conn, audio_dir: audio_dir} do
    broadcast =
      insert_broadcast!(%{
        kind: "referee_whistle",
        text: "Scheidsrechters! U mag affluiten!"
      })

    conn = get(conn, ~p"/broadcasts/#{broadcast.id}/audio")

    assert response(conn, 200) == "fake mp3"
    assert File.exists?(Path.join(audio_dir, "referee-whistle.mp3"))
    assert [content_type] = get_resp_header(conn, "content-type")
    assert content_type =~ "audio/mpeg"
  end

  test "player marks a broadcast as played", %{conn: conn} do
    broadcast = insert_broadcast!(%{})

    {:ok, view, _html} = live(conn, ~p"/broadcasts/player")
    render_hook(view, "mark_played", %{"id" => broadcast.id})

    updated = Broadcasts.get_broadcast!(broadcast.id)
    assert updated.status == "played"
    assert updated.played_at
  end

  defp insert_broadcast!(attrs) do
    defaults = %{
      kind: "round_announcement",
      round_starts_at: ~U[2026-05-23 10:00:00Z],
      target_round_starts_at: ~U[2026-05-23 10:00:00Z],
      scheduled_for: ~U[2026-05-23 09:45:00Z],
      status: "pending",
      text: "Omroep tekst"
    }

    %Broadcast{}
    |> Broadcast.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end
end
