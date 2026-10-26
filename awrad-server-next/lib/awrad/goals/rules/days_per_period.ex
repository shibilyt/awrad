defmodule Awrad.Goals.Rules.DaysPerPeriod do
  @moduledoc false
  # Rule: days per period (fixtures/days_per_period.json).

  alias Awrad.Goals.DaysPerPeriodStanding
  alias Awrad.Goals.Goal
  alias Awrad.Goals.Rules.Counts
  alias Awrad.Goals.Rules.Periods
  alias Awrad.Goals.Rules.Schedule
  alias Awrad.Hijri.Corrections

  @spec standing(Goal.t(), Counts.index(), Date.t(), Goal.week_start(), Corrections.t()) ::
          DaysPerPeriodStanding.t()
  def standing(
        %Goal{requirement: {:days_per_period, unit, days}} = goal,
        index,
        date,
        week_start,
        corrections
      ) do
    with %Date.Range{} = window <-
           Periods.window(goal.active_period, unit, date, week_start, corrections),
         {qualifying, required} when required > 0 <-
           tally(goal, index, window, date, days, corrections) do
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
  # Hijri month), or one without due days (fully paused or unscheduled):
  # like every `:not_due` answer, its window is the day itself.
  defp not_due(date),
    do: %DaysPerPeriodStanding{
      status: :not_due,
      window: Periods.day(date),
      qualifying_days: 0,
      required_days: 0
    }

  @doc """
  `{qualifying, required}` for `window`: the due days up to `date` meeting the
  daily target, and `days` capped by the window's due days (pauses, the
  schedule and a partial first or last period reduce it).
  """
  @spec tally(
          Goal.t(),
          Counts.index(),
          Date.Range.t(),
          Date.t(),
          pos_integer(),
          Corrections.t()
        ) :: {non_neg_integer(), non_neg_integer()}
  def tally(goal, index, window, date, days, corrections) do
    due_days = Enum.filter(window, &Schedule.due?(goal, &1, corrections))

    qualifying =
      due_days
      |> Enum.take_while(&(not Date.after?(&1, date)))
      |> Enum.count(&Counts.day_met?(goal, Counts.day(index, &1), :target))

    {qualifying, min(days, length(due_days))}
  end
end
