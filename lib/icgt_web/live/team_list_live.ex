defmodule IcgtWeb.TeamListLive do
  use IcgtWeb, :live_view

  alias Icgt.Tournaments

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :teams, Tournaments.list_teams())}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <main class="min-h-screen bg-base-200 px-4 py-6 text-base-content">
      <section class="mx-auto max-w-5xl rounded-box bg-base-100 p-5 shadow">
        <div class="flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p class="text-sm font-semibold uppercase tracking-wide text-base-content/60">Teams</p>
            <h1 class="mt-1 text-3xl font-semibold">Teambeheer</h1>
          </div>
          <.link navigate={~p"/broadcasts/player"} class="btn btn-soft btn-sm">Omroep</.link>
        </div>

        <div class="mt-5 overflow-x-auto">
          <table class="table">
            <thead>
              <tr>
                <th>Team</th>
                <th>Omroepnaam</th>
                <th>Contactpersonen</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={team <- @teams}>
                <td class="font-medium">{team.name}</td>
                <td>{team.broadcast_name || "-"}</td>
                <td>{team.contact_people_count}</td>
                <td class="text-right">
                  <.link navigate={~p"/teams/#{team.id}"} class="btn btn-primary btn-sm">
                    Open
                  </.link>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </main>
    """
  end
end
