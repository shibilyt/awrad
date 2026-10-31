defmodule Awrad.Goals.Rules.Ring do
  @moduledoc false
  # Rule: what a My Goals ring fills toward today (fixtures/today_ring.json,
  # decision 33). Every ring means today, judged by today's version.

  alias Awrad.Goals.Goal
  alias Awrad.Goals.Ring
  alias Awrad.Goals.Rules.Counts
  alias Awrad.Goals.Rules.Pace
  alias Awrad.Goals.Rules.Periods
  alias Awrad.Goals.Rules.Schedule
  alias Awrad.Goals.Rules.Versions
  alias Awrad.Goals.Session
  alias Awrad.Goals.Timeline
  alias Awrad.Hijri.Corrections

  @spec today(Timeline.t(), Counts.index(), Date.t(), Goal.week_start(), Corrections.t()) ::
          Ring.t()
  def today(%Timeline{} = timeline, index, date, week_start, corrections) do
    goal = Versions.resolve(timeline, date)
    counts = Counts.day(index, date)
    none = %Ring{ring: :none, progress: Counts.goal_total(goal, counts), goal: nil}

    case goal.requirement do
      {:period_total, period} ->
        window = period_window(goal, period, date, week_start, corrections)

        if window &&
             Enum.any?(window, &Schedule.due?(Versions.resolve(timeline, &1), &1, corrections)),
           do: period_ring(goal, index, Periods.through(window, date)),
           else: none

      _daily ->
        if Schedule.due?(goal, date, corrections),
          do: day_ring(timeline, goal, {index, counts}, date, corrections),
          else: none
    end
  end

  defp period_window(%Goal{active_period: active}, period, date, week_start, corrections) do
    with true <- Periods.in_active_period?(active, date),
         %Date.Range{} = full <- Periods.period(date, period, week_start, corrections) do
      Periods.clip(full, active)
    else
      _no_window -> nil
    end
  end

  defp period_ring(%Goal{sessions: []} = goal, index, days) do
    progress = Counts.sum(index, days, &Counts.goal_total(goal, &1))
    %Ring{ring: :period_target, progress: progress, goal: goal.count_policy.target}
  end

  defp period_ring(%Goal{sessions: sessions}, index, days) do
    combined(
      sessions,
      &Counts.sum(index, days, fn day -> Map.get(day, &1.id, 0) end),
      :period_target
    )
  end

  defp day_ring(
         _timeline,
         %Goal{requirement: :per_due_date} = goal,
         {_index, counts},
         _date,
         _corrections
       ),
       do: target_ring(goal, counts)

  defp day_ring(
         _timeline,
         %Goal{requirement: {:days_per_period, _, _}} = goal,
         {_index, counts},
         _date,
         _corrections
       ),
       do: target_ring(goal, counts)

  defp day_ring(
         timeline,
         %Goal{requirement: :cumulative_total} = goal,
         {index, counts},
         date,
         corrections
       ) do
    amount = Pace.streak_amount(timeline, index, goal.count_policy, date, corrections)
    ring = if goal.count_policy.streak_threshold == :daily_pace, do: :pace, else: :streak_amount
    %Ring{ring: ring, progress: Counts.goal_total(goal, counts), goal: amount}
  end

  # A tracker shows its number until it's reached, and never with any count.
  defp day_ring(timeline, %Goal{requirement: :tracker} = goal, {index, counts}, date, corrections) do
    progress = Counts.goal_total(goal, counts)

    with threshold when threshold != :any_count <- goal.count_policy.streak_threshold,
         amount when progress < amount <-
           Pace.streak_amount(timeline, index, goal.count_policy, date, corrections) do
      %Ring{ring: :streak_amount, progress: progress, goal: amount}
    else
      _no_number -> %Ring{ring: :none, progress: progress, goal: nil}
    end
  end

  defp target_ring(%Goal{sessions: []} = goal, counts),
    do: %Ring{
      ring: :target,
      progress: Counts.goal_total(goal, counts),
      goal: goal.count_policy.target
    }

  defp target_ring(%Goal{sessions: sessions}, counts),
    do: combined(sessions, &Map.get(counts, &1.id, 0), :target)

  # Sessions combined: their targets, each counting up to its own.
  defp combined(sessions, progress_of, ring) do
    %Ring{
      ring: ring,
      progress:
        Counts.total(sessions, fn %Session{target: target} = s -> min(progress_of.(s), target) end),
      goal: Counts.total(sessions, & &1.target)
    }
  end
end
