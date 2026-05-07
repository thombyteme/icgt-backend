defmodule Icgt.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      IcgtWeb.Telemetry,
      Icgt.Repo,
      {DNSCluster, query: Application.get_env(:icgt, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Icgt.PubSub},
      # Start a worker by calling: Icgt.Worker.start_link(arg)
      # {Icgt.Worker, arg},
      # Start to serve requests, typically the last entry
      IcgtWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Icgt.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    IcgtWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
