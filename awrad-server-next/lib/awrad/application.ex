defmodule Awrad.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  # Top-level boundary: the only place that wires the domain and the web edge together.
  use Boundary, top_level?: true, deps: [Awrad, AwradWeb]

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AwradWeb.Telemetry,
      Awrad.Repo,
      {DNSCluster, query: Application.get_env(:awrad, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Awrad.PubSub},
      # Background email delivery (Awrad.Accounts.UserNotifier).
      {Task.Supervisor, name: Awrad.TaskSupervisor},
      Awrad.Pruner,
      # Deletes abandoned and unreferenced recordings (slice 3c).
      Awrad.Audio.Cleaner,
      # Start to serve requests, typically the last entry
      AwradWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Awrad.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AwradWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
