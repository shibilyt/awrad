defmodule Awrad.Goals.Rules.Counts do
  @moduledoc false
  # Count entries indexed by day, and whether a count meets a count policy.

  alias Awrad.Goals.CountEntry
  alias Awrad.Goals.CountPolicy
  alias Awrad.Goals.Goal

  @typedoc "One day's counts by session (`nil` for the goal itself)."
  @type day :: %{optional(String.t() | nil) => non_neg_integer()}
  @type index :: %{optional(Date.t()) => day()}

  @typedoc "`:target` meets the policy's target; `:streak` meets its streak threshold."
  @type measure :: :target | :streak

  @spec index([CountEntry.t()]) :: index()
  def index(entries) do
    Enum.reduce(entries, %{}, fn %CountEntry{date: date, session: session, count: count}, acc ->
      Map.update(
        acc,
        date,
        %{session => count},
        &Map.update(&1, session, count, fn n -> n + count end)
      )
    end)
  end

  @spec day(index(), Date.t()) :: day()
  def day(index, date), do: Map.get(index, date, %{})

  @doc "The goal's own total on a day: every entry without sessions, its sessions' entries with them."
  @spec goal_total(Goal.t(), day()) :: non_neg_integer()
  def goal_total(%Goal{sessions: []}, day), do: total(Map.values(day), & &1)

  def goal_total(%Goal{sessions: sessions}, day),
    do: total(sessions, &Map.get(day, &1.id, 0))

  @doc "A total over `days`, taking each day's count with `fun`."
  @spec sum(index(), [Date.t()], (day() -> non_neg_integer())) :: non_neg_integer()
  def sum(index, days, fun), do: total(days, &fun.(day(index, &1)))

  # Like Enum.sum_by/2, but typed as whole counts (Enum.sum_by/2 returns number()).
  defp total(items, count_of) do
    Enum.reduce(items, 0, fn item, total ->
      case count_of.(item) do
        count when is_integer(count) and count >= 0 -> total + count
      end
    end)
  end

  @doc """
  Whether `count` meets the policy. A `nil` target is a tracker: any positive
  count. A valid goal's streak threshold always has its value (`Goal.new/1`).
  """
  @spec meets?(non_neg_integer(), CountPolicy.t(), measure()) :: boolean()
  def meets?(count, %CountPolicy{target: nil}, :target), do: count > 0
  def meets?(count, %CountPolicy{target: target}, :target), do: count >= target
  def meets?(count, %CountPolicy{streak_threshold: :any_count}, :streak), do: count > 0

  def meets?(count, %CountPolicy{streak_threshold: threshold} = policy, :streak),
    do: count >= Map.fetch!(policy, threshold)

  @doc "Whether a day meets the goal: its own policy, or every session its own."
  @spec day_met?(Goal.t(), day(), measure()) :: boolean()
  def day_met?(%Goal{sessions: []} = goal, day, measure),
    do: meets?(goal_total(goal, day), goal.count_policy, measure)

  def day_met?(%Goal{sessions: sessions}, day, measure),
    do: Enum.all?(sessions, &meets?(Map.get(day, &1.id, 0), &1.count_policy, measure))
end
