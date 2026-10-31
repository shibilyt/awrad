defmodule Awrad.Goals.Rules.ExcusedDays do
  @moduledoc false
  # Rule: whether a day can be excused or un-excused (fixtures/excused_days.json,
  # decision 20). The checks run in the README's order; the reason is the first
  # that fails.

  alias Awrad.Goals.DayStatus
  alias Awrad.Goals.Goal
  alias Awrad.Goals.Rules.Counts
  alias Awrad.Goals.Rules.DayStatuses
  alias Awrad.Goals.Rules.Periods
  alias Awrad.Goals.Rules.Schedule
  alias Awrad.Goals.Rules.Versions
  alias Awrad.Goals.Timeline
  alias Awrad.Hijri.Corrections

  @per_month 2

  @type excuse_error ::
          :goal_finished
          | :not_past
          | :already_excused
          | :not_available
          | :not_due
          | :not_missed
          | :limit_reached

  @spec excuse(Timeline.t(), Counts.index(), Date.t(), Date.t(), Corrections.t()) ::
          :ok | {:error, excuse_error()}
  def excuse(%Timeline{} = timeline, index, date, day, corrections) do
    cond do
      finished?(timeline, date) -> {:error, :goal_finished}
      not Date.before?(day, date) -> {:error, :not_past}
      day in timeline.excused -> {:error, :already_excused}
      true -> excusable(timeline, index, date, day, corrections)
    end
  end

  defp excusable(timeline, index, date, day, corrections) do
    goal = Versions.resolve(timeline, day)

    cond do
      match?({:period_total, _}, Versions.resolve(timeline, date).requirement) ->
        {:error, :not_available}

      not Schedule.due?(goal, day, corrections) ->
        {:error, :not_due}

      kept?(timeline, goal, index, {date, day}, corrections) ->
        {:error, :not_missed}

      excused_in_month(timeline, day) >= @per_month ->
        {:error, :limit_reached}

      true ->
        :ok
    end
  end

  @spec unexcuse(Timeline.t(), Date.t(), Date.t()) ::
          :ok | {:error, :goal_finished | :not_excused}
  def unexcuse(%Timeline{} = timeline, date, day) do
    cond do
      finished?(timeline, date) -> {:error, :goal_finished}
      day in timeline.excused -> :ok
      true -> {:error, :not_excused}
    end
  end

  # Ended in the document, or past its last day.
  defp finished?(%Timeline{ended: ended} = timeline, date) do
    last = Periods.last_day(Versions.resolve(timeline, date).active_period)
    ended != nil or (last != nil and Date.after?(date, last))
  end

  # Days per period judges a day by whether it qualified; other goals by its
  # status with make-up. A day pending make-up isn't kept.
  defp kept?(
         _timeline,
         %Goal{requirement: {:days_per_period, _, _}} = goal,
         index,
         {_date, day},
         _corrections
       ),
       do: Counts.day_met_target?(goal, Counts.day(index, day))

  defp kept?(timeline, %Goal{}, index, {date, day}, corrections) do
    timeline
    |> DayStatuses.statuses(index, date, corrections)
    |> Enum.find(&(&1.date == day))
    |> then(fn %DayStatus{status: status} -> DayStatus.kept?(status) end)
  end

  # The limit is per Gregorian month of the excused day.
  defp excused_in_month(%Timeline{excused: excused}, %Date{year: year, month: month}),
    do: Enum.count(excused, &(&1.year == year and &1.month == month))
end
