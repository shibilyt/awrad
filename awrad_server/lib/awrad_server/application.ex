defmodule AwradServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AwradServerWeb.Telemetry,
      AwradServer.Repo,
      AwradServer.Dhikr.BuiltInRegistryGuard,
      {DNSCluster, query: Application.get_env(:awrad_server, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: AwradServer.PubSub},
      # Start a worker by calling: AwradServer.Worker.start_link(arg)
      # {AwradServer.Worker, arg},
      # Start to serve requests, typically the last entry
      AwradServerWeb.Endpoint
    ]

    children =
      if Application.get_env(:awrad_server, :progress_sync_maintenance_enabled, true),
        do: List.insert_at(children, -1, AwradServer.ProgressSync.Maintenance),
        else: children

    children =
      if Application.get_env(:awrad_server, :built_in_registry_guard_enabled, true),
        do: children,
        else: List.delete(children, AwradServer.Dhikr.BuiltInRegistryGuard)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AwradServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AwradServerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
