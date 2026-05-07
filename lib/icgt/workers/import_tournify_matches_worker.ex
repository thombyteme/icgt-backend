defmodule Icgt.Workers.ImportTournifyMatchesWorker do
  @moduledoc false
  use Oban.Worker, queue: :scrapers, max_attempts: 3

  require Logger

  alias Icgt.Tournaments.Importers.TournifyHtml

  @impl Oban.Worker
  def perform(_job) do
    case TournifyHtml.import() do
      {:ok, %{imported: imported, failed: failed, total: total}} ->
        Logger.info(
          "Imported Tournify matches via Oban: imported=#{imported} failed=#{failed} total=#{total}"
        )

        :ok

      {:error, reason} ->
        Logger.error("Failed Tournify match import via Oban: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
