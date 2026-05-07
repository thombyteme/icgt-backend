defmodule Mix.Tasks.Tournaments.ImportMatchesHtml do
  use Mix.Task

  alias Icgt.Tournaments.Importers.TournifyHtml

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

    with {:ok, %{imported: imported, failed: failed, total: total}} <-
           TournifyHtml.import(url: url, wait_ms: wait_ms) do
      Mix.shell().info("Imported #{imported}/#{total} matches (failed: #{failed}).")
    else
      {:error, reason} ->
        Mix.raise("HTML scrape import failed: #{inspect(reason)}")
    end
  end
end
