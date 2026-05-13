defmodule IcgtWeb.BroadcastPlayerLive do
  use IcgtWeb, :live_view

  alias Icgt.Broadcasts

  @refresh_ms 1_000

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Icgt.PubSub, Broadcasts.topic())
      Process.send_after(self(), :refresh, @refresh_ms)
    end

    {:ok, assign_broadcasts(socket)}
  end

  @impl Phoenix.LiveView
  def handle_event("mark_played", %{"id" => id}, socket) do
    case id |> to_string() |> Integer.parse() do
      {broadcast_id, ""} -> Broadcasts.mark_played(broadcast_id)
      _ -> :ok
    end

    {:noreply, assign_broadcasts(socket)}
  end

  def handle_event("mark_played", _params, socket), do: {:noreply, socket}

  @impl Phoenix.LiveView
  def handle_info({:broadcast_changed, _broadcast}, socket) do
    {:noreply, assign_broadcasts(socket)}
  end

  def handle_info(:refresh, socket) do
    Process.send_after(self(), :refresh, @refresh_ms)
    {:noreply, assign_broadcasts(socket)}
  end

  defp assign_broadcasts(socket) do
    playable = Broadcasts.list_playable_broadcasts()

    socket
    |> assign(:broadcasts, Broadcasts.list_player_broadcasts())
    |> assign(:playable, playable)
    |> assign(:current, List.first(playable))
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <main class="min-h-screen bg-base-200 px-4 py-6 text-base-content">
      <div
        id="broadcast-player"
        phx-hook="BroadcastPlayer"
        data-current-id={@current && @current.id}
        data-current-audio-url={@current && ~p"/broadcasts/#{@current.id}/audio"}
        class="mx-auto flex max-w-5xl flex-col gap-6"
      >
        <section class="rounded-box bg-base-100 p-5 shadow">
          <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <p class="text-sm font-semibold uppercase tracking-wide text-base-content/60">
                Omroep
              </p>
              <h1 class="mt-1 text-3xl font-semibold">Broadcast player</h1>
            </div>
            <button id="broadcast-start-button" type="button" class="btn btn-primary">
              Start audio
            </button>
          </div>

          <div class="mt-5 rounded-box border border-base-300 bg-base-200 p-4">
            <p id="broadcast-player-status" class="text-sm font-medium">
              Wacht op audio.
            </p>
            <p :if={@current} class="mt-2 text-lg font-semibold">
              Volgende: {label(@current)}
            </p>
            <p :if={@current} class="mt-2 whitespace-pre-line text-sm leading-6 text-base-content/75">
              {@current.text}
            </p>
          </div>
        </section>

        <section class="rounded-box bg-base-100 p-5 shadow">
          <h2 class="text-xl font-semibold">Wachtrij</h2>
          <div class="mt-4 overflow-x-auto">
            <table class="table">
              <thead>
                <tr>
                  <th>Tijd</th>
                  <th>Type</th>
                  <th>Status</th>
                  <th>Tekst</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={broadcast <- @broadcasts}>
                  <td class="whitespace-nowrap align-top">
                    {format_datetime(broadcast.scheduled_for)}
                  </td>
                  <td class="whitespace-nowrap align-top">{kind_label(broadcast.kind)}</td>
                  <td class="align-top">
                    <span class={status_class(broadcast.status)}>{broadcast.status}</span>
                  </td>
                  <td class="whitespace-pre-line break-words leading-6">{broadcast.text}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </main>
    """
  end

  defp label(broadcast) do
    "#{kind_label(broadcast.kind)} om #{format_datetime(broadcast.scheduled_for)}"
  end

  defp kind_label("round_announcement"), do: "Wedstrijden"
  defp kind_label("referee_whistle"), do: "Affluiten"
  defp kind_label(kind), do: kind

  defp status_class("generated"), do: "badge badge-info"
  defp status_class("played"), do: "badge badge-success"
  defp status_class("failed"), do: "badge badge-error"
  defp status_class(_), do: "badge"

  defp format_datetime(nil), do: "-"

  defp format_datetime(%DateTime{} = datetime),
    do: format_datetime_parts(DateTime.to_date(datetime), datetime)

  defp format_datetime(%NaiveDateTime{} = datetime),
    do: format_datetime_parts(NaiveDateTime.to_date(datetime), datetime)

  defp format_datetime(_datetime), do: "-"

  defp format_datetime_parts(date, datetime) do
    "#{weekday_name(date)} #{Calendar.strftime(datetime, "%d-%m-%Y %H:%M")}"
  end

  defp weekday_name(date) do
    case Date.day_of_week(date) do
      1 -> "Maandag"
      2 -> "Dinsdag"
      3 -> "Woensdag"
      4 -> "Donderdag"
      5 -> "Vrijdag"
      6 -> "Zaterdag"
      7 -> "Zondag"
    end
  end
end
