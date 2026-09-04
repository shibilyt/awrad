defmodule AwradServer.Practice.Eligibility do
  @moduledoc "Rules for the subset of goal counting supported by the web companion."

  alias AwradServer.Tracking.{Goal, GoalSlot}

  @doc "Returns whether a goal has a scheduled occurrence on the supplied date."
  def due?(%Goal{} = goal, %Date{} = date) do
    goal.is_active and is_nil(goal.completed_at) and not before_start?(date, goal.start_date) and
      not expired?(date, goal.end_date) and not duration_ended?(goal, date) and
      scheduled_on?(goal, date)
  end

  @doc "Returns whether a goal slot can receive a manual browser increment."
  def evaluate(%Goal{} = goal, %GoalSlot{} = slot, %Date{} = date) do
    cond do
      not goal.is_active ->
        {:blocked, :paused}

      not is_nil(goal.completed_at) ->
        {:blocked, :completed}

      not is_nil(goal.deleted_at) ->
        {:blocked, :deleted}

      before_start?(date, goal.start_date) ->
        {:blocked, :future_start}

      not slot.is_active or not is_nil(slot.deleted_at) or not is_nil(slot.archived_at) ->
        {:blocked, :unsupported_slot}

      slot.slot_type != "anytime" or slot.timing_type != "anytime" ->
        {:blocked, :unsupported_slot}

      expired?(date, goal.end_date) ->
        {:blocked, :expired}

      duration_ended?(goal, date) ->
        {:blocked, :duration_ended}

      scheduled_on?(goal, date) ->
        :allowed

      true ->
        {:blocked, :off_recurrence}
    end
  end

  defp duration_ended?(%Goal{duration_days: nil}, _date), do: false

  defp duration_ended?(%Goal{start_date: start_date, duration_days: duration_days}, date) do
    Date.diff(date, start_date) >= duration_days
  end

  defp before_start?(_date, nil), do: false
  defp before_start?(date, start_date), do: Date.compare(date, start_date) == :lt

  defp expired?(_date, nil), do: false
  defp expired?(date, end_date), do: Date.compare(date, end_date) == :gt

  defp scheduled_on?(%Goal{recurrence_frequency: "daily"}, _date), do: true

  defp scheduled_on?(%Goal{recurrence_frequency: "weekly", recurrence_weekdays: []}, _date),
    do: true

  defp scheduled_on?(%Goal{recurrence_frequency: "weekly", recurrence_weekdays: weekdays}, date) do
    Date.day_of_week(date) in weekdays
  end

  defp scheduled_on?(
         %Goal{
           recurrence_frequency: "monthly",
           recurrence_calendar: "gregorian",
           recurrence_month_days: month_days
         },
         _date
       )
       when month_days in [nil, []],
       do: true

  defp scheduled_on?(
         %Goal{
           recurrence_frequency: "monthly",
           recurrence_calendar: "gregorian",
           recurrence_month_days: month_days
         },
         date
       ) do
    date.day in month_days
  end

  defp scheduled_on?(
         %Goal{
           recurrence_frequency: "yearly",
           recurrence_calendar: "gregorian",
           recurrence_month: month,
           recurrence_month_days: month_days
         },
         date
       )
       when month_days in [nil, []] do
    is_nil(month) or date.month == month
  end

  defp scheduled_on?(
         %Goal{
           recurrence_frequency: "yearly",
           recurrence_calendar: "gregorian",
           recurrence_month: month,
           recurrence_month_days: month_days
         },
         date
       ) do
    (is_nil(month) or date.month == month) and date.day in month_days
  end

  defp scheduled_on?(
         %Goal{
           recurrence_frequency: "specific_dates",
           recurrence_calendar: "gregorian",
           recurrence_specific_dates: specific_dates
         },
         date
       ) do
    date in (specific_dates || [])
  end

  defp scheduled_on?(
         %Goal{
           recurrence_frequency: "interval",
           recurrence_interval_days: interval,
           recurrence_anchor_date: anchor_date,
           start_date: start_date
         },
         date
       )
       when is_integer(interval) and interval > 0 do
    anchor_date = anchor_date || start_date
    days_since_anchor = Date.diff(date, anchor_date)
    days_since_anchor >= 0 and rem(days_since_anchor, interval) == 0
  end

  defp scheduled_on?(_goal, _date), do: false
end
