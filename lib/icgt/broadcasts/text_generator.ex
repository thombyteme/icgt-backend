defmodule Icgt.Broadcasts.TextGenerator do
  @moduledoc false

  def round_announcement(round_starts_at, matches) do
    time_text = round_time_text(local_round_time(round_starts_at, matches))

    match_lines =
      matches
      |> Enum.sort_by(&field_sort_key/1)
      |> Enum.map_join("\n", &match_line/1)

    [
      "Voetballiefhebbers!",
      "Graag jullie aandacht voor de wedstrijden van de ronde van #{time_text}.",
      match_lines,
      "Teams, scheidsrechters en toeschouwers, succes en veel plezier!"
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  def referee_whistle, do: "Scheidsrechters! U mag affluiten!"

  def round_time_text(%DateTime{} = datetime) do
    datetime
    |> DateTime.to_time()
    |> time_text()
  end

  def round_time_text(%NaiveDateTime{} = datetime) do
    datetime
    |> NaiveDateTime.to_time()
    |> time_text()
  end

  def round_time_text(_), do: "onbekende tijd"

  defp time_text(%Time{minute: 0} = time), do: "#{spoken_hour(time.hour)} uur"

  defp time_text(%Time{minute: 30} = time) do
    hour =
      time.hour
      |> Kernel.+(1)
      |> spoken_hour()

    "half #{hour}"
  end

  defp time_text(%Time{} = time), do: Calendar.strftime(time, "%H:%M")

  defp spoken_hour(hour) do
    case rem(hour, 12) do
      0 -> 12
      value -> value
    end
  end

  defp match_line(match) do
    field = field_text(match.field)
    poule = match.poule |> value_or_fallback("onbekende klasse") |> poule_text()
    team_a = team_name(match, :team_a, :team_a_name)
    team_b = team_name(match, :team_b, :team_b_name)

    referee =
      case blank?(match.referee) do
        true -> "."
        false -> " onder begeleiding van #{String.trim(match.referee)}."
      end

    "Op #{field} spelen de volgende teams uit #{poule} tegen elkaar. #{team_a} tegen #{team_b}#{referee}"
  end

  defp poule_text(text) do
    text
    |> String.replace(~r/\bPoule\b/i, "Pool")
    |> String.replace(" -", "")
  end

  defp team_name(match, team_assoc, fallback_field) do
    broadcast_name =
      match
      |> Map.get(team_assoc)
      |> broadcast_name()

    value_or_fallback(
      broadcast_name,
      value_or_fallback(Map.get(match, fallback_field), "onbekend team")
    )
  end

  defp broadcast_name(%Ecto.Association.NotLoaded{}), do: nil
  defp broadcast_name(nil), do: nil
  defp broadcast_name(team), do: Map.get(team, :broadcast_name)

  defp local_round_time(round_starts_at, matches) do
    matches
    |> Enum.find_value(& &1.starts_at_local)
    |> case do
      nil -> round_starts_at
      starts_at_local -> starts_at_local
    end
  end

  defp field_text(nil), do: "een onbekend veld"

  defp field_text(field) when is_binary(field) do
    case String.trim(field) do
      "" -> "een onbekend veld"
      value -> "veld #{value}"
    end
  end

  defp value_or_fallback(nil, fallback), do: fallback

  defp value_or_fallback(value, fallback) when is_binary(value) do
    case String.trim(value) do
      "" -> fallback
      trimmed -> trimmed
    end
  end

  defp blank?(nil), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""

  defp field_sort_key(match) do
    case match.field do
      nil -> {1, 0, ""}
      field -> {0, field_number(field), field}
    end
  end

  defp field_number(field) when is_binary(field) do
    case Regex.run(~r/\d+/, field) do
      [number] -> String.to_integer(number)
      _ -> 0
    end
  end
end
