defmodule Awrad.Goals.Rules.Streak do
  @moduledoc false
  # Rule: the current streak (fixtures/goal_streak.json).
  #
  # Walks back from the evaluated date over due units: due days, or weeks,
  # months and Hijri months with at least one due day. A met unit adds one;
  # the unit still in progress never breaks the streak; any other unmet unit
  # ends it. Days that aren't due (unscheduled, paused, outside the active
  # period, outside the Hijri table for a Hijri schedule) are skipped.

  alias Awrad.Goals.Goal
  alias Awrad.Goals.Rules.Counts
  alias Awrad.Goals.Rules.DaysPerPeriod
  alias Awrad.Goals.Rules.Periods
  alias Awrad.Goals.Rules.Requirement
  alias Awrad.Goals.Rules.Schedule
  alias Awrad.Hijri
  alias Awrad.Hijri.Corrections

  @spec current(Goal.t(), Counts.index(), Date.t(), Goal.week_start(), Corrections.t()) ::
          non_neg_integer()
  def current(
        %Goal{requirement: {:period_total, unit}} = goal,
        index,
        date,
        week_start,
        corrections
      ) do
    periods(
      goal,
      date,
      {unit, week_start, corrections},
      &Requirement.window_met?(goal, index, &1, date)
    )
  end

  def current(
        %Goal{requirement: {:days_per_period, unit, days}} = goal,
        index,
        date,
        week_start,
        corrections
      ) do
    periods(goal, date, {unit, week_start, corrections}, fn window ->
      {qualifying, required} = DaysPerPeriod.tally(goal, index, window, date, days, corrections)
      qualifying >= required
    end)
  end

  def current(%Goal{} = goal, index, date, _week_start, corrections) do
    case last_unit_day(goal, date) do
      nil ->
        0

      last ->
        last
        |> Date.range(goal.active_period.start_date, -1)
        |> Stream.filter(&Schedule.due?(goal, &1, corrections))
        |> Enum.reduce_while(0, fn day, streak ->
          met? = Counts.day_met?(goal, Counts.day(index, day), :streak)
          step(streak, met?, Date.compare(day, date) == :eq)
        end)
    end
  end

  defp periods(goal, date, {unit, week_start, corrections} = calendar, met?) do
    case last_unit_day(goal, date) do
      nil ->
        0

      last ->
        last = last_period_day(unit, last, corrections)
        walk(goal, Periods.period(last, unit, week_start, corrections), {date, calendar, met?}, 0)
    end
  end

  # Days after the Hijri table have no Hijri month, so they're never due: the
  # walk starts from the table's last month instead.
  defp last_period_day(:hijri_month, last, corrections),
    do: Periods.earliest(last, Hijri.days(corrections).last)

  defp last_period_day(_unit, last, _corrections), do: last

  # Periods before the start date don't overlap the active period, and days
  # before the Hijri table have no Hijri month: stop there.
  defp walk(_goal, nil = _full_period, _context, streak), do: streak

  defp walk(goal, full_period, {_date, {unit, week_start, corrections}, _met?} = context, streak) do
    with %Date.Range{} = window <- Periods.clip(full_period, goal.active_period),
         {:cont, streak} <- visit(goal, window, context, streak) do
      previous = Periods.period(Date.add(full_period.first, -1), unit, week_start, corrections)
      walk(goal, previous, context, streak)
    else
      nil -> streak
      {:halt, streak} -> streak
    end
  end

  # A period without a due day (fully paused or unscheduled) is skipped.
  defp visit(goal, window, {date, {_unit, _week_start, corrections}, met?}, streak) do
    if Enum.any?(window, &Schedule.due?(goal, &1, corrections)),
      do: step(streak, met?.(window), not Date.before?(window.last, date)),
      else: {:cont, streak}
  end

  defp step(streak, true = _met?, _in_progress?), do: {:cont, streak + 1}
  defp step(streak, false, true = _in_progress?), do: {:cont, streak}
  defp step(streak, false, false), do: {:halt, streak}

  # The latest day a unit can end on: the evaluated date, or the active
  # period's last day once it's over. `nil` before the start date.
  defp last_unit_day(%Goal{active_period: period}, date) do
    last = Periods.earliest(date, Periods.last_day(period))
    if Date.before?(last, period.start_date), do: nil, else: last
  end
end
