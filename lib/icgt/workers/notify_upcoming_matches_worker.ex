defmodule Icgt.Workers.NotifyUpcomingMatchesWorker do
  @moduledoc false
  use Oban.Worker, queue: :notifications, max_attempts: 3

  require Logger

  alias Icgt.Notifications
  alias Icgt.Notifications.TwilioWhatsapp
  alias Icgt.Tournaments

  @impl Oban.Worker
  def perform(_job) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    window_start = DateTime.add(now, 10 * 60, :second)
    window_end = DateTime.add(window_start, 59, :second)

    matches = Tournaments.list_matches_starting_between(window_start, window_end)

    results = Enum.map(matches, &notify_match/1)

    if Enum.any?(results, &match?({:error, _}, &1)) do
      {:error, :notification_failures}
    else
      :ok
    end
  end

  defp notify_match(match) do
    contacts = collect_contacts(match)

    if contacts == [] do
      Logger.warning("Match #{match.id} has no contact people, skipping notification send.")
      {:ok, :no_contacts}
    else
      send_results =
        Enum.map(contacts, fn contact ->
          send_once(match, contact)
        end)

      if Enum.any?(send_results, &match?({:error, _}, &1)) do
        {:error, {:match_send_failed, match.id}}
      else
        case Notifications.all_sent_for_contacts?(match.id, Enum.map(contacts, & &1.id)) do
          true ->
            _ = Tournaments.mark_captains_notified(match.id)
            {:ok, :sent}

          false ->
            {:error, {:match_not_fully_sent, match.id}}
        end
      end
    end
  end

  defp send_once(match, contact) do
    if Notifications.sent?(match.id, contact.id) do
      {:ok, :already_sent}
    else
      body = build_message(match, contact)

      case TwilioWhatsapp.send_message(contact.phone_number, body) do
        {:ok, provider_message_id} ->
          _ = Notifications.mark_sent(match.id, contact.id, provider_message_id)
          {:ok, :sent}

        {:error, reason} ->
          _ = Notifications.mark_failed(match.id, contact.id, inspect(reason))

          Logger.error(
            "Failed whatsapp send for match=#{match.id} contact=#{contact.id}: #{inspect(reason)}"
          )

          {:error, reason}
      end
    end
  end

  defp collect_contacts(match) do
    team_a_contacts = if match.team_a, do: match.team_a.contact_people, else: []
    team_b_contacts = if match.team_b, do: match.team_b.contact_people, else: []

    (team_a_contacts ++ team_b_contacts)
    |> Enum.uniq_by(& &1.id)
    |> Enum.filter(&valid_phone_number?/1)
  end

  defp valid_phone_number?(contact) do
    is_binary(contact.phone_number) and String.trim(contact.phone_number) != ""
  end

  defp build_message(match, contact) do
    starts_at_text =
      case match.starts_at_local do
        %NaiveDateTime{} = dt -> Calendar.strftime(dt, "%d-%m-%Y %H:%M")
        _ -> "onbekende tijd"
      end

    [
      "Hoi #{contact.name},",
      "Je team speelt over 10 minuten.",
      "Wedstrijd: #{match.team_a_name} vs #{match.team_b_name}",
      "Veld: #{match.field || "-"}",
      "Start: #{starts_at_text}"
    ]
    |> Enum.join("\n")
  end
end
