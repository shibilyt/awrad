defmodule Awrad.Goals.Rules.Counts do
  @moduledoc false
  # Count entries indexed by day, and what a day's count is measured against.

  alias Awrad.Goals.CountEntry
  alias Awrad.Goals.CountPolicy
  alias Awrad.Goals.Goal
  alias Awrad.Goals.Session

  @typedoc "One day's counts by session (`nil` for the goal itself)."
  @type day :: %{optional(String.t() | nil) => non_neg_integer()}
  @type index :: %{optional(Date.t()) => day()}

  @typedoc """
  What a day is judged in: the goal itself (`nil`) with its count policy, or
  each session with the policy its target stands for.
  """
  @type unit :: {String.t() | nil, CountPolicy.t()}

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

  @doc "Every count of the day, with or without a session."
  @spec day_total(day()) :: non_neg_integer()
  def day_total(day), do: total(Map.values(day), & &1)

  @doc "The goal's own total on a day: every entry without sessions, its sessions' entries with them."
  @spec goal_total(Goal.t(), day()) :: non_neg_integer()
  def goal_total(%Goal{sessions: []}, day), do: day_total(day)
  def goal_total(%Goal{sessions: sessions}, day), do: total(sessions, &Map.get(day, &1.id, 0))

  @doc "A total over `days`, taking each day's count with `fun`."
  @spec sum(index(), Enumerable.t(Date.t()), (day() -> non_neg_integer())) :: non_neg_integer()
  def sum(index, days, fun), do: total(days, &fun.(day(index, &1)))

  @doc "Like `Enum.sum_by/2`, but typed as whole counts (`Enum.sum_by/2` returns `number()`)."
  @spec total(Enumerable.t(item), (item -> non_neg_integer())) :: non_neg_integer()
        when item: term()
  def total(items, count_of) do
    Enum.reduce(items, 0, fn item, total ->
      case count_of.(item) do
        count when is_integer(count) and count >= 0 -> total + count
      end
    end)
  end

  @spec units(Goal.t()) :: [unit(), ...]
  def units(%Goal{sessions: [], count_policy: policy}), do: [{nil, policy}]
  def units(%Goal{sessions: sessions}), do: Enum.map(sessions, &{&1.id, session_policy(&1)})

  @doc "A session has a target only: it's also its streak amount (any count without one)."
  @spec session_policy(Session.t()) :: CountPolicy.t()
  def session_policy(%Session{target: target}) do
    %CountPolicy{
      minimum: nil,
      target: target,
      maximum: nil,
      streak_threshold: if(is_nil(target), do: :any_count, else: :target)
    }
  end

  @spec unit_count(Goal.t(), day(), String.t() | nil) :: non_neg_integer()
  def unit_count(goal, day, nil), do: goal_total(goal, day)
  def unit_count(_goal, day, id), do: Map.get(day, id, 0)

  @doc "Whether `count` meets a target. No target (a tracker) is any positive count."
  @spec meets_target?(non_neg_integer(), non_neg_integer() | nil) :: boolean()
  def meets_target?(count, nil), do: count > 0
  def meets_target?(count, target), do: count >= target

  @doc "Whether the day met its target: the goal's, or every session's. A tracker's is any count."
  @spec day_met_target?(Goal.t(), day()) :: boolean()
  def day_met_target?(%Goal{} = goal, day) do
    Enum.all?(units(goal), fn {id, policy} ->
      meets_target?(
        unit_count(goal, day, id),
        unless(goal.requirement == :tracker, do: policy.target)
      )
    end)
  end

  @doc "The target a single day has: per-due-date and days-per-period goals only."
  @spec daily_target(Goal.t(), CountPolicy.t()) :: non_neg_integer() | nil
  def daily_target(%Goal{requirement: :per_due_date}, policy), do: policy.target
  def daily_target(%Goal{requirement: {:days_per_period, _, _}}, policy), do: policy.target
  def daily_target(%Goal{}, _policy), do: nil
end
