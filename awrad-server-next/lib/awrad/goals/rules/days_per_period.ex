defmodule Awrad.Goals.Rules.DaysPerPeriod do
  @moduledoc false
  # Rule: days per period (fixtures/days_per_period.json).

  alias Awrad.Goals.DaysPerPeriodStanding
  alias Awrad.Goals.Goal
  alias Awrad.Goals.Rules.Counts
  alias Awrad.Goals.Rules.Periods
  alias Awrad.Goals.Rules.Schedule

  @spec standing(Goal.t(), Counts.index(), Date.t(), Goal.week_start()) ::
          DaysPerPeriodStanding.t()
  def standing(%Goal{requirement: {:days_per_period, unit, days}} = goal, index, date, week_start) do
    window = window(goal.active_period, unit, date, week_start)
    {qualifying, required} = tally(goal, index, window, date, days)

    if required == 0 do
      not_due(date)
    else
      %DaysPerPeriodStanding{
        status: if(qualifying >= required, do: :met, else: :not_met),
        window: window,
        qualifying_days: qualifying,
        required_days: required
      }
    end
  end

  # A window without due days (outside the active period, or fully paused or
  # unscheduled): like every `:not_due` answer, its window is the day itself.
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
  @spec tally(Goal.t(), Counts.index(), Date.Range.t(), Date.t(), pos_integer()) ::
          {non_neg_integer(), non_neg_integer()}
  def tally(goal, index, window, date, days) do
    due_days = Enum.filter(window, &Schedule.due?(goal, &1))

    qualifying =
      due_days
      |> Enum.take_while(&(not Date.after?(&1, date)))
      |> Enum.count(&Counts.day_met?(goal, Counts.day(index, &1), :target))

    {qualifying, min(days, length(due_days))}
  end

  # Outside the active period the window is the day itself, which isn't due.
  defp window(period, unit, date, week_start) do
    if Periods.in_active_period?(period, date) do
      date |> Periods.period(unit, week_start) |> Periods.clip(period) || Periods.day(date)
    else
      Periods.day(date)
    end
  end
end
