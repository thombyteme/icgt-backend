defmodule Icgt.Repo do
  use Ecto.Repo,
    otp_app: :icgt,
    adapter: Ecto.Adapters.Postgres
end
