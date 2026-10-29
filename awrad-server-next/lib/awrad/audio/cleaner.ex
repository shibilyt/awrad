defmodule Awrad.Audio.Cleaner do
  @moduledoc """
  Runs the recordings cleanup (`Awrad.Audio.Cleanup`) every 10 minutes, and
  soon after an account is deleted (`wake/0`). Disabled in tests
  (`config :awrad, Awrad.Audio.Cleaner`), which run `Awrad.Audio.clean/1`
  themselves.
  """

  use GenServer

  require Logger

  @interval :timer.minutes(10)

  @doc false
  @spec start_link(keyword()) :: GenServer.on_start() | :ignore
  def start_link(opts) do
    if Keyword.fetch!(Application.fetch_env!(:awrad, __MODULE__), :enabled),
      do: GenServer.start_link(__MODULE__, opts, name: __MODULE__),
      else: :ignore
  end

  @doc "Asks the running job to clean up now. Does nothing when it isn't running."
  @spec wake() :: :ok
  def wake do
    if Process.whereis(__MODULE__), do: send(__MODULE__, :clean)
    :ok
  end

  @impl GenServer
  def init(_opts) do
    {:ok, schedule()}
  end

  @impl GenServer
  def handle_info(:clean, timer) do
    if timer, do: Process.cancel_timer(timer)
    result = Awrad.Audio.clean()

    if result.marked + result.deleted + result.failed > 0,
      do: Logger.info("audio cleanup: #{inspect(result)}")

    {:noreply, schedule()}
  end

  defp schedule, do: Process.send_after(self(), :clean, @interval)
end
