defmodule Coinchette.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CoinchetteWeb.Telemetry,
      Coinchette.Repo,
      {DNSCluster, query: Application.get_env(:coinchette, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Coinchette.PubSub},
      # Start a worker by calling: Coinchette.Worker.start_link(arg)
      # {Coinchette.Worker, arg},
      # Start to serve requests, typically the last entry
      CoinchetteWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Coinchette.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CoinchetteWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
