defmodule Icgt.FakeTournifyImporter do
  def import do
    {:ok, %{imported: 1, failed: 0, total: 1}}
  end
end
