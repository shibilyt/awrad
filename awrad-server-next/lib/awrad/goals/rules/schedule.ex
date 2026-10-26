defmodule Awrad.Goals.Rules.Schedule do
  @moduledoc false
  # Rule: is due (fixtures/goal_is_due.json).

  alias Awrad.Goals.Goal
  alias Awrad.Goals.PausedRange
  alias Awrad.Goals.Rules.Periods
  alias Awrad.Hijri
  alias Awrad.Hijri.Corrections
  alias Awrad.Hijri.HijriDate

  @weekdays {:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday}

  @spec due?(Goal.t(), Date.t(), Corrections.t()) :: boolean()
  def due?(%Goal{active_period: period} = goal, date, corrections) do
    Periods.in_active_period?(period, date) and not paused?(goal.paused, date) and
      scheduled?(goal.schedule, period.start_date, date, corrections)
  end

  defp paused?(ranges, date), do: Enum.any?(ranges, &in_pause?(&1, date))

  defp in_pause?(%PausedRange{from: from, to: to}, date),
    do: not Date.before?(date, from) and (is_nil(to) or not Date.after?(date, to))

  defp scheduled?(:every_day, _start, _date, _corrections), do: true
  defp scheduled?(:one_time, _start, _date, _corrections), do: true

  defp scheduled?({:weekdays, weekdays}, _start, date, _corrections),
    do: elem(@weekdays, Date.day_of_week(date) - 1) in weekdays

  defp scheduled?({:every_n_days, every, anchor}, start, date, _corrections) do
    days = Date.diff(date, anchor || start)
    days >= 0 and rem(days, every) == 0
  end

  defp scheduled?({:month_days, days}, _start, %Date{day: day} = date, _corrections),
    do: month_day?(days, day, Date.days_in_month(date))

  defp scheduled?({:specific_dates, dates}, _start, date, _corrections), do: date in dates

  defp scheduled?({:yearly, :gregorian, ranges}, _start, %Date{} = date, _corrections),
    do: yearly?(ranges, {date.month, date.day}, Date.days_in_month(date))

  # Hijri schedules are never due outside the Hijri table.
  defp scheduled?({:hijri_month_days, days}, _start, date, corrections) do
    case Hijri.date(date, corrections) do
      %HijriDate{} = hijri -> month_day?(days, hijri.day, hijri.month_length)
      nil -> false
    end
  end

  defp scheduled?({:yearly, :hijri, ranges}, _start, date, corrections) do
    case Hijri.date(date, corrections) do
      %HijriDate{} = hijri -> yearly?(ranges, {hijri.month, hijri.day}, hijri.month_length)
      nil -> false
    end
  end

  # A day past the month's end falls on its last day (the 31st is 30 April;
  # Hijri day 30 is the 29th in a 29-day month).
  defp month_day?(days, day, month_length),
    do: day in days or (day == month_length and Enum.any?(days, &(&1 > day)))

  defp yearly?(ranges, month_day, month_length),
    do: Enum.any?(ranges, &in_range?(&1, month_day, month_length))

  # Inclusive. Whether a range runs over the year end depends on its declared
  # days, before clamping (`{month, day}` tuples compare in calendar order).
  defp in_range?({from, to}, month_day, month_length) do
    from? = clamp(from, month_day, month_length) <= month_day
    to? = month_day <= clamp(to, month_day, month_length)

    if to < from, do: from? or to?, else: from? and to?
  end

  # A range boundary in the evaluated day's own month falls on its last day
  # when the month is shorter (29 February in a common year, Hijri day 30).
  defp clamp({month, day}, {month, _day}, month_length), do: {month, min(day, month_length)}
  defp clamp(boundary, _month_day, _month_length), do: boundary
end
