defmodule Awrad.Pruner do
  @moduledoc """
  Deletes expired rows every hour: idempotency results, email codes,
  rate-limit windows, deleted accounts' refresh tokens (ADR 0010) and sync
  receipts older than 90 days. Expired rows are already ignored when read
  (sync receipts excepted: their 90 days are the retention itself). Disabled
  in tests (`config :awrad, Awrad.Pruner`).
  """

  use GenServer

  require Logger

  alias Awrad.{Accounts, Idempotency, Sync}

  @interval :timer.hours(1)

  @doc false
  @spec start_link(keyword()) :: GenServer.on_start() | :ignore
  def start_link(opts) do
    if Keyword.fetch!(Application.fetch_env!(:awrad, __MODULE__), :enabled),
      do: GenServer.start_link(__MODULE__, opts, name: __MODULE__),
      else: :ignore
  end

  @doc "Prunes once. Returns how many rows were deleted."
  @spec prune(DateTime.t()) :: non_neg_integer()
  def prune(now \\ DateTime.utc_now(:second)),
    do: Idempotency.prune(now) + Accounts.prune(now) + Sync.prune(now)

  @impl GenServer
  def init(_opts) do
    schedule()
    {:ok, nil}
  end

  @impl GenServer
  def handle_info(:prune, state) do
    count = prune()
    if count > 0, do: Logger.info("pruned #{count} expired account rows")
    schedule()
    {:noreply, state}
  end

  defp schedule, do: Process.send_after(self(), :prune, @interval)
end
