defmodule Awrad.Goals.Rules.Pace do
  @moduledoc false
  # Rule: daily pace (fixtures/daily_pace.json), and the streak amount a day
  # needs, which is the pace for `:daily_pace` (README "Streaks").

  alias Awrad.Goals.CountPolicy
  alias Awrad.Goals.DailyPace
  alias Awrad.Goals.Goal
  alias Awrad.Goals.Rules.Counts
  alias Awrad.Goals.Rules.Periods
  alias Awrad.Goals.Rules.Schedule
  alias Awrad.Goals.Rules.Versions
  alias Awrad.Goals.Timeline
  alias Awrad.Hijri.Corrections

  @doc """
  The pace on `date`, judged against the end its version had then, even after
  the goal ended early. It leaves out the day's own counts, so it doesn't
  shrink while counting.
  """
  @spec daily(Timeline.t(), Counts.index(), Date.t(), Corrections.t()) :: DailyPace.t()
  def daily(%Timeline{} = timeline, index, date, corrections) do
    case Versions.resolve(timeline, date, false) do
      %Goal{requirement: :cumulative_total, sessions: []} = goal ->
        total_pace(timeline, goal, index, date, corrections)

      %Goal{} ->
        %DailyPace{pace: nil, remaining: nil, due_days_left: nil}
    end
  end

  defp total_pace(timeline, %Goal{active_period: period} = goal, index, date, corrections) do
    before =
      period.start_date
      |> Date.range(Date.add(date, -1), 1)
      |> Enum.filter(&Periods.in_active_period?(period, &1))
      |> then(&Counts.sum(index, &1, fn day -> Counts.goal_total(goal, day) end))

    remaining = max(0, goal.count_policy.target - before)

    case Periods.last_day(period) do
      nil ->
        %DailyPace{pace: nil, remaining: remaining, due_days_left: nil}

      last ->
        left = due_days_left(timeline, Periods.latest(date, period.start_date), last, corrections)
        due? = Schedule.due?(goal, date, corrections)
        pace = if due? and left > 0, do: ceil_div(remaining, left)
        %DailyPace{pace: pace, remaining: remaining, due_days_left: left}
    end
  end

  defp due_days_left(timeline, from, last, corrections) do
    Enum.count(Date.range(from, last, 1), fn day ->
      Schedule.due?(Versions.resolve(timeline, day, false), day, corrections)
    end)
  end

  defp ceil_div(amount, by), do: div(amount + by - 1, by)

  @doc """
  What a day needs to keep the streak under `policy` (the goal's, or a
  session's): 1 for any count, the policy's own minimum, target or maximum,
  `{:amount, n}`'s n, or that day's pace share, at least 1.
  """
  @spec streak_amount(Timeline.t(), Counts.index(), CountPolicy.t(), Date.t(), Corrections.t()) ::
          non_neg_integer()
  def streak_amount(timeline, index, %CountPolicy{} = policy, date, corrections) do
    case policy.streak_threshold do
      {:amount, amount} -> amount
      :any_count -> 1
      :daily_pace -> max(1, daily(timeline, index, date, corrections).pace || 1)
      threshold -> Map.fetch!(policy, threshold)
    end
  end
end
