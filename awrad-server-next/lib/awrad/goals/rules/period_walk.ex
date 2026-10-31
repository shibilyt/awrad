defmodule Awrad.Goals.Rules.PeriodWalk do
  @moduledoc false
  # A period goal's weeks or months (period totals, days per period), newest
  # first from the evaluated date, for streaks and consistency.
  #
  # The walk starts at the evaluated date, or the last day once the goal is
  # over, and stops before the start date (or the Hijri table). A period with
  # no due day, or one whose excused days leave it needing none, is skipped.
  # Each period is judged by the version in force on its last day so far.

  alias Awrad.Goals.Goal
  alias Awrad.Goals.Rules.DaysPerPeriod
  alias Awrad.Goals.Rules.Periods
  alias Awrad.Goals.Rules.Requirement
  alias Awrad.Goals.Rules.Schedule
  alias Awrad.Goals.Rules.Versions
  alias Awrad.Goals.Timeline
  alias Awrad.Hijri
  alias Awrad.Hijri.Corrections

  @type period :: %{window: Date.Range.t(), in_progress?: boolean(), met?: boolean()}

  @spec back(Timeline.t(), map(), Date.t(), Goal.week_start(), Corrections.t()) ::
          Enumerable.t(period())
  def back(%Timeline{} = timeline, index, date, week_start, corrections) do
    %Goal{active_period: active, requirement: requirement} = Versions.resolve(timeline, date)
    unit = elem(requirement, 1)
    last = Periods.earliest(date, Periods.last_day(active))

    if Date.before?(last, active.start_date) do
      []
    else
      first =
        Periods.period(last_period_day(unit, last, corrections), unit, week_start, corrections)

      first
      |> Stream.unfold(fn
        nil -> nil
        full -> {full, Periods.period(Date.add(full.first, -1), unit, week_start, corrections)}
      end)
      |> Stream.map(&Periods.clip(&1, active))
      |> Stream.take_while(&(&1 != nil))
      |> Stream.flat_map(&visit(timeline, index, &1, date, corrections))
    end
  end

  # Days after the Hijri table have no Hijri month, so they're never due: the
  # walk starts from the table's last month instead.
  defp last_period_day(:hijri_month, last, corrections),
    do: Periods.earliest(last, Hijri.days(corrections).last)

  defp last_period_day(_unit, last, _corrections), do: last

  defp visit(timeline, index, window, date, corrections) do
    if Enum.any?(window, &Schedule.due?(Versions.resolve(timeline, &1), &1, corrections)) and
         needs_a_day?(timeline, index, window, date, corrections) do
      [
        %{
          window: window,
          in_progress?: not Date.before?(window.last, date),
          met?: met?(timeline, index, window, date, corrections)
        }
      ]
    else
      []
    end
  end

  defp needs_a_day?(timeline, index, window, date, corrections) do
    case Versions.resolve(timeline, date) do
      %Goal{requirement: {:days_per_period, _unit, _days}} ->
        elem(DaysPerPeriod.tally(timeline, index, window, date, corrections), 1) > 0

      %Goal{} ->
        true
    end
  end

  defp met?(timeline, index, window, date, corrections) do
    case Versions.resolve(timeline, Periods.earliest(date, window.last)) do
      %Goal{requirement: {:days_per_period, _unit, _days}} ->
        {qualifying, required} = DaysPerPeriod.tally(timeline, index, window, date, corrections)
        qualifying >= required

      goal ->
        Requirement.window_met?(goal, index, window, date)
    end
  end
end
