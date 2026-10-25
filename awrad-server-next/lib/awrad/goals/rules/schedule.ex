defmodule Awrad.Goals.Rules.Schedule do
  @moduledoc false
  # Rule: is due (fixtures/goal_is_due.json).

  alias Awrad.Goals.Goal
  alias Awrad.Goals.PausedRange
  alias Awrad.Goals.Rules.Periods

  @weekdays {:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday}

  @spec due?(Goal.t(), Date.t()) :: boolean()
  def due?(%Goal{active_period: period} = goal, date) do
    Periods.in_active_period?(period, date) and not paused?(goal.paused, date) and
      scheduled?(goal.schedule, period.start_date, date)
  end

  defp paused?(ranges, date), do: Enum.any?(ranges, &in_pause?(&1, date))

  defp in_pause?(%PausedRange{from: from, to: to}, date),
    do: not Date.before?(date, from) and (is_nil(to) or not Date.after?(date, to))

  defp scheduled?(:every_day, _start, _date), do: true
  defp scheduled?(:one_time, _start, _date), do: true

  defp scheduled?({:weekdays, weekdays}, _start, date),
    do: elem(@weekdays, Date.day_of_week(date) - 1) in weekdays

  defp scheduled?({:every_n_days, every, anchor}, start, date) do
    days = Date.diff(date, anchor || start)
    days >= 0 and rem(days, every) == 0
  end

  # A day past the month's end falls on its last day (the 31st is 30 April).
  defp scheduled?({:month_days, days}, _start, %Date{day: day} = date) do
    day in days or (day == Date.days_in_month(date) and Enum.any?(days, &(&1 > day)))
  end

  defp scheduled?({:specific_dates, dates}, _start, date), do: date in dates
end
