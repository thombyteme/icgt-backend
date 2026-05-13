defmodule Icgt.Workers.NotifyUpcomingMatchesWorker do
  @moduledoc false
  use Oban.Worker, queue: :notifications, max_attempts: 3

  require Logger

  alias Icgt.AmsterdamTime
  alias Icgt.Notifications
  alias Icgt.Notifications.WhatsAppBusiness
  alias Icgt.Tournaments

  @impl Oban.Worker
  def perform(_job) do
    now = AmsterdamTime.now()
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
    recipients = collect_recipients(match)

    if recipients == [] do
      Logger.warning("Match #{match.id} has no contact people, skipping notification send.")
      {:ok, :no_contacts}
    else
      send_results =
        Enum.map(recipients, fn recipient ->
          send_once(match, recipient)
        end)

      if Enum.any?(send_results, &match?({:error, _}, &1)) do
        {:error, {:match_send_failed, match.id}}
      else
        contact_ids = Enum.map(recipients, & &1.contact.id)

        case Notifications.all_sent_for_contacts?(match.id, contact_ids) do
          true ->
            _ = Tournaments.mark_captains_notified(match.id)
            {:ok, :sent}

          false ->
            {:error, {:match_not_fully_sent, match.id}}
        end
      end
    end
  end

  defp send_once(match, recipient) do
    contact = recipient.contact

    if Notifications.sent?(match.id, contact.id) do
      {:ok, :already_sent}
    else
      variables = template_variables(match, recipient)

      case WhatsAppBusiness.send_match_notification(contact.phone_number, variables) do
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

  defp collect_recipients(match) do
    []
    |> add_team_recipients(match.team_a, match.team_a_name, match.team_b, match.team_b_name)
    |> add_team_recipients(match.team_b, match.team_b_name, match.team_a, match.team_a_name)
    |> Enum.filter(&valid_phone_number?(&1.contact))
    |> Enum.uniq_by(& &1.contact.id)
  end

  defp valid_phone_number?(contact) do
    is_binary(contact.phone_number) and String.trim(contact.phone_number) != ""
  end

  defp add_team_recipients(recipients, nil, _team_name, _opponent, _opponent_name), do: recipients

  defp add_team_recipients(recipients, team, team_name, opponent, opponent_name) do
    team_display_name = display_team_name(team, team_name)
    opponent_display_name = display_team_name(opponent, opponent_name)

    team.contact_people
    |> Enum.map(fn contact ->
      %{
        contact: contact,
        team: team_display_name,
        opponent_team: opponent_display_name
      }
    end)
    |> Kernel.++(recipients)
  end

  defp template_variables(match, recipient) do
    %{
      "team" => recipient.team,
      "veld_nummer" => field_number(match.field),
      "tegenstander_team" => recipient.opponent_team
    }
  end

  defp display_team_name(team, fallback_name) do
    [team_value(team, :broadcast_name), team_value(team, :name), fallback_name]
    |> Enum.find_value(&present_string/1) || "onbekend team"
  end

  defp team_value(nil, _field), do: nil
  defp team_value(team, field), do: Map.get(team, field)

  defp field_number(nil), do: "-"
  defp field_number(field), do: present_string(field) || "-"

  defp present_string(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp present_string(_value), do: nil
end
