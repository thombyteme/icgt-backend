defmodule IcgtWeb.BroadcastAudioController do
  use IcgtWeb, :controller

  alias Icgt.Broadcasts

  def show(conn, %{"id" => id}) do
    broadcast = Broadcasts.get_broadcast!(id)

    case Broadcasts.audio_for_broadcast(broadcast) do
      {:file, path} ->
        conn
        |> put_resp_content_type("audio/mpeg")
        |> send_file(200, path)

      {:binary, audio} ->
        conn
        |> put_resp_content_type("audio/mpeg")
        |> send_resp(200, audio)

      {:error, reason} ->
        conn
        |> put_status(:bad_gateway)
        |> text("Audio generation failed: #{inspect(reason)}")
    end
  end
end
