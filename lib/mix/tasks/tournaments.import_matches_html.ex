defmodule Mix.Tasks.Tournaments.ImportMatchesHtml do
  use Mix.Task

  alias Icgt.Tournaments

  @shortdoc "Prototype: imports matches by scraping rendered Tournify HTML with Playwright"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        strict: [url: :string, wait_ms: :integer],
        aliases: [u: :url]
      )

    url =
      opts[:url] ||
        "https://tournifyapp.com/live/ariebonkenburgtoernooi/schedule"

    wait_ms = opts[:wait_ms] || 12_000

    with {:ok, payload} <- scrape(url, wait_ms) do
      {ok_count, error_count} =
        Enum.reduce(payload["matches"] || [], {0, 0}, fn row, {ok_acc, err_acc} ->
          attrs = to_match_attrs(row)

          case Tournaments.upsert_match(attrs) do
            {:ok, _record} -> {ok_acc + 1, err_acc}
            {:error, _changeset} -> {ok_acc, err_acc + 1}
          end
        end)

      total = length(payload["matches"] || [])
      Mix.shell().info("Imported #{ok_count}/#{total} matches (failed: #{error_count}).")
    else
      {:error, reason} ->
        Mix.raise("HTML scrape import failed: #{inspect(reason)}")
    end
  end

  defp scrape(url, wait_ms) do
    script_path = Path.expand("priv/scripts/scrape_tournify_schedule.js")

    case System.cmd("node", [script_path, "--url", url, "--waitMs", Integer.to_string(wait_ms)],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        Jason.decode(output)

      {output, code} ->
        {:error, {:node_failed, code, output}}
    end
  end

  defp to_match_attrs(row) do
    date_iso = row["dateIso"]
    st = row["st"]
    timezone = "Europe/Amsterdam"
    starts_at_local = build_local_datetime(date_iso, st)
    starts_at = local_to_utc(starts_at_local, timezone)
    unique_key = build_unique_key(row)

    %{
      source: "tournify_html",
      external_id: unique_key,
      unique_key: unique_key,
      starts_at: starts_at,
      starts_at_local: starts_at_local,
      timezone: timezone,
      field: normalize_field(row["field"]),
      date_iso: parse_date(date_iso),
      poule: row["poule"],
      referee: row["referee"],
      team_a_name: row["teamA"],
      team_b_name: row["teamB"],
      status: row["status"] || "scheduled",
      raw_data: row
    }
  end

  defp parse_date(nil), do: nil

  defp parse_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp build_local_datetime(date_iso, st) when is_binary(date_iso) and is_binary(st) do
    with {:ok, date} <- Date.from_iso8601(date_iso),
         {:ok, time} <- Time.from_iso8601(st <> ":00") do
      NaiveDateTime.new!(date, time)
    else
      _ -> nil
    end
  end

  defp build_local_datetime(_, _), do: nil

  defp local_to_utc(nil, _timezone), do: nil

  defp local_to_utc(local, timezone) do
    case DateTime.from_naive(local, timezone) do
      {:ok, datetime} -> DateTime.shift_zone!(datetime, "Etc/UTC")
      {:ambiguous, first, _second} -> DateTime.shift_zone!(first, "Etc/UTC")
      {:gap, before, _after} -> DateTime.shift_zone!(before, "Etc/UTC")
      {:error, :utc_only_time_zone_database} -> DateTime.from_naive!(local, "Etc/UTC")
    end
  end

  defp normalize_field(nil), do: nil

  defp normalize_field(field) when is_binary(field) do
    field
    |> String.trim()
    |> String.replace(~r/^veld\s+/i, "")
  end

  defp build_unique_key(row) do
    field = normalize_field(row["field"]) || "unknown-field"
    date = row["dateIso"] || "unknown-date"
    time = row["st"] || "unknown-time"
    team_a = row["teamA"] || "unknown-team-a"
    team_b = row["teamB"] || "unknown-team-b"

    "html:#{date}:#{time}:#{field}:#{team_a}:#{team_b}"
  end
end
