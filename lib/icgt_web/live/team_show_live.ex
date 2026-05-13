defmodule IcgtWeb.TeamShowLive do
  use IcgtWeb, :live_view

  alias Icgt.Broadcasts
  alias Icgt.Tournaments

  @impl Phoenix.LiveView
  def mount(%{"id" => id}, _session, socket) do
    team = Tournaments.get_team!(id)

    {:ok,
     socket
     |> assign(:team, team)
     |> assign(:team_form, to_form(Tournaments.change_team(team)))
     |> assign(:new_contact_form, empty_contact_form())}
  end

  @impl Phoenix.LiveView
  def handle_event("save_team", %{"team" => params}, socket) do
    case Tournaments.update_team(socket.assigns.team, params) do
      {:ok, _team} ->
        _ = Broadcasts.materialize_all_broadcasts()

        {:noreply,
         socket
         |> put_flash(:info, "Team opgeslagen.")
         |> reload_team()}

      {:error, changeset} ->
        {:noreply, assign(socket, :team_form, to_form(changeset))}
    end
  end

  def handle_event("save_contact", %{"contact" => %{"id" => ""} = params}, socket) do
    case Tournaments.create_team_contact_person(socket.assigns.team, Map.delete(params, "id")) do
      {:ok, _contact} ->
        {:noreply,
         socket
         |> put_flash(:info, "Contactpersoon toegevoegd.")
         |> reload_team()}

      {:error, changeset} ->
        {:noreply, assign(socket, :new_contact_form, to_form(changeset, as: :contact))}
    end
  end

  def handle_event("save_contact", %{"contact" => %{"id" => id} = params}, socket) do
    contact = Tournaments.get_team_contact_person!(socket.assigns.team, id)

    case Tournaments.update_team_contact_person(contact, params) do
      {:ok, _contact} ->
        {:noreply,
         socket
         |> put_flash(:info, "Contactpersoon opgeslagen.")
         |> reload_team()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Contactpersoon kon niet worden opgeslagen.")}
    end
  end

  def handle_event("delete_contact", %{"id" => id}, socket) do
    contact = Tournaments.get_team_contact_person!(socket.assigns.team, id)
    {:ok, _contact} = Tournaments.delete_team_contact_person(contact)

    {:noreply,
     socket
     |> put_flash(:info, "Contactpersoon verwijderd.")
     |> reload_team()}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <main class="min-h-screen bg-base-200 px-4 py-6 text-base-content">
      <div class="mx-auto flex max-w-5xl flex-col gap-6">
        <section class="rounded-box bg-base-100 p-5 shadow">
          <.link navigate={~p"/teams"} class="link text-sm">Terug naar teams</.link>
          <div class="mt-3 flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <p class="text-sm font-semibold uppercase tracking-wide text-base-content/60">Team</p>
              <h1 class="mt-1 text-3xl font-semibold">{@team.name}</h1>
            </div>
          </div>

          <.form
            for={@team_form}
            id="team-form"
            phx-submit="save_team"
            class="mt-5 grid gap-4 sm:grid-cols-2"
          >
            <.input field={@team_form[:name]} label="Naam" />
            <.input field={@team_form[:broadcast_name]} label="Omroepnaam" />
            <div class="sm:col-span-2">
              <.button type="submit">Team opslaan</.button>
            </div>
          </.form>
        </section>

        <section class="rounded-box bg-base-100 p-5 shadow">
          <h2 class="text-xl font-semibold">Contactpersonen</h2>

          <div class="mt-4 flex flex-col divide-y divide-base-300">
            <div :for={contact <- @team.contact_people} class="py-4">
              <.form
                for={contact_form(contact)}
                id={"contact-form-#{contact.id}"}
                phx-submit="save_contact"
                class="grid gap-3 sm:grid-cols-[1fr_1fr_auto]"
              >
                <.input field={contact_form(contact)[:id]} type="hidden" />
                <.input field={contact_form(contact)[:name]} label="Naam" />
                <.input field={contact_form(contact)[:phone_number]} label="Telefoonnummer" />
                <div class="flex items-end gap-2">
                  <.button type="submit">Opslaan</.button>
                  <button
                    type="button"
                    class="btn btn-error btn-soft"
                    phx-click="delete_contact"
                    phx-value-id={contact.id}
                    data-confirm="Contactpersoon verwijderen?"
                  >
                    Verwijder
                  </button>
                </div>
              </.form>
            </div>
          </div>

          <div class="mt-5 rounded-box border border-base-300 bg-base-200 p-4">
            <h3 class="font-semibold">Nieuwe contactpersoon</h3>
            <.form
              for={@new_contact_form}
              id="new-contact-form"
              phx-submit="save_contact"
              class="mt-3 grid gap-3 sm:grid-cols-[1fr_1fr_auto]"
            >
              <.input field={@new_contact_form[:id]} type="hidden" />
              <.input field={@new_contact_form[:name]} label="Naam" />
              <.input field={@new_contact_form[:phone_number]} label="Telefoonnummer" />
              <div class="flex items-end">
                <.button type="submit">Toevoegen</.button>
              </div>
            </.form>
          </div>
        </section>
      </div>
    </main>
    """
  end

  defp reload_team(socket) do
    team = Tournaments.get_team!(socket.assigns.team.id)

    socket
    |> assign(:team, team)
    |> assign(:team_form, to_form(Tournaments.change_team(team)))
    |> assign(:new_contact_form, empty_contact_form())
  end

  defp contact_form(contact) do
    to_form(
      %{
        "id" => contact.id,
        "name" => contact.name,
        "phone_number" => contact.phone_number
      },
      as: :contact,
      id: "contact_#{contact.id}"
    )
  end

  defp empty_contact_form do
    to_form(%{"id" => "", "name" => "", "phone_number" => ""}, as: :contact, id: "new_contact")
  end
end
