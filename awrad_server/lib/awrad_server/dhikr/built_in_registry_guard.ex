defmodule AwradServer.Dhikr.BuiltInRegistryGuard do
  @moduledoc """
  Installs and validates the canonical built-in registry before serving traffic.

  Startup fails on a key/UUID conflict so a production release cannot accept
  sync commands against a partially seeded catalog.
  """

  use GenServer

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  def init(:ok) do
    AwradServer.Dhikr.BuiltInRegistry.seed!()
    {:ok, %{seeded: true}}
  end
end
