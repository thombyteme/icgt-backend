defmodule Icgt.Workers.ImportTournifyMatchesWorker do
  @moduledoc false
  use Oban.Worker, queue: :scrapers, max_attempts: 3

  require Logger

  alias Icgt.Broadcasts
  alias Icgt.Tournaments.Importers.TournifyHtml

  @impl Oban.Worker
  def perform(_job) do
    importer = Application.get_env(:icgt, :tournify_importer, TournifyHtml)

    case importer.import() do
      {:ok, %{imported: imported, failed: failed, total: total}} ->
        materialized = Broadcasts.materialize_all_broadcasts()

        Logger.info(
          "Imported Tournify matches via Oban: imported=#{imported} failed=#{failed} total=#{total} broadcasts=#{inspect(materialized)}"
        )

        if Enum.any?(materialized, &match?({:error, _}, &1)) do
          {:error, :broadcast_materialization_failed}
        else
          :ok
        end

      {:error, reason} ->
        Logger.error("Failed Tournify match import via Oban: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
