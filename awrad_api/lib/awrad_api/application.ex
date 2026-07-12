defmodule AwradApi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AwradApiWeb.Telemetry,
      AwradApi.Repo,
      {DNSCluster, query: Application.get_env(:awrad_api, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: AwradApi.PubSub},
      # Start a worker by calling: AwradApi.Worker.start_link(arg)
      # {AwradApi.Worker, arg},
      # Start to serve requests, typically the last entry
      AwradApiWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AwradApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AwradApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
