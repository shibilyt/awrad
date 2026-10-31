defmodule Awrad.Goals.Rules.DaysPerPeriod do
  @moduledoc false
  # Rule: days per period (fixtures/days_per_period.json).

  alias Awrad.Goals.DaysPerPeriodStanding
  alias Awrad.Goals.Goal
  alias Awrad.Goals.Rules.Counts
  alias Awrad.Goals.Rules.Periods
  alias Awrad.Goals.Rules.Schedule
  alias Awrad.Goals.Rules.Versions
  alias Awrad.Goals.Timeline
  alias Awrad.Hijri.Corrections

  @spec standing(Goal.t(), Counts.index(), Date.t(), Goal.week_start(), Corrections.t()) ::
          DaysPerPeriodStanding.t()
  def standing(
        %Goal{requirement: {:days_per_period, unit, _days}} = goal,
        index,
        date,
        week_start,
        corrections
      ) do
    with %Date.Range{} = window <-
           Periods.window(goal.active_period, unit, date, week_start, corrections),
         {qualifying, required} when required > 0 <-
           tally(Timeline.from_goal(goal), index, window, date, corrections) do
      %DaysPerPeriodStanding{
        status: if(qualifying >= required, do: :met, else: :not_met),
        window: window,
        qualifying_days: qualifying,
        required_days: required
      }
    else
      _no_due_days -> not_due(date)
    end
  end

  # No window (outside the active period, or outside the Hijri table for a
  # Hijri month), or one that needs no day (fully paused, unscheduled or
  # excused): like every `:not_due` answer, its window is the day itself.
  defp not_due(date),
    do: %DaysPerPeriodStanding{
      status: :not_due,
      window: Periods.day(date),
      qualifying_days: 0,
      required_days: 0
    }

  @doc """
  `{qualifying, required}` for `window`: the due days up to `date` meeting
  their daily target, and the required days of the version in force on the
  window's last day so far, less the window's excused days, capped by its due
  days (pauses, the schedule and a partial first or last period reduce it).
  """
  @spec tally(Timeline.t(), Counts.index(), Date.Range.t(), Date.t(), Corrections.t()) ::
          {non_neg_integer(), non_neg_integer()}
  def tally(%Timeline{} = timeline, index, window, date, corrections) do
    %Goal{requirement: {:days_per_period, _unit, days}} =
      Versions.resolve(timeline, Periods.earliest(date, window.last))

    due_days =
      Enum.filter(window, &Schedule.due?(Versions.resolve(timeline, &1), &1, corrections))

    qualifying =
      due_days
      |> Periods.through(date)
      |> Enum.count(
        &Counts.day_met_target?(Versions.resolve(timeline, &1), Counts.day(index, &1))
      )

    excused = Enum.count(window, &(&1 in timeline.excused))

    {qualifying, max(0, min(days - excused, length(due_days)))}
  end
end
