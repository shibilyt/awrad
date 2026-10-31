defmodule Awrad.Goals.Rules.Periods do
  @moduledoc false
  # Shared calendar arithmetic for the rules: active-period bounds and
  # week, month and Hijri-month windows.

  alias Awrad.Goals.ActivePeriod
  alias Awrad.Goals.Goal
  alias Awrad.Hijri
  alias Awrad.Hijri.Corrections

  @doc "The active period's last day: the earlier of the end date and start + duration − 1."
  @spec last_day(ActivePeriod.t()) :: Date.t() | nil
  def last_day(%ActivePeriod{end_date: end_date} = period),
    do: earliest(end_date, duration_end(period))

  @spec in_active_period?(ActivePeriod.t(), Date.t()) :: boolean()
  def in_active_period?(%ActivePeriod{start_date: start} = period, date) do
    not Date.before?(date, start) and not after_last_day?(period, date)
  end

  @doc """
  The whole week, month or Hijri month containing `date`. A day outside the
  Hijri table has no Hijri month (`nil`).
  """
  @spec period(Date.t(), Goal.period(), Goal.week_start(), Corrections.t()) ::
          Date.Range.t() | nil
  def period(date, :week, week_start, _corrections),
    do:
      Date.range(Date.beginning_of_week(date, week_start), Date.end_of_week(date, week_start), 1)

  def period(date, :month, _week_start, _corrections),
    do: Date.range(Date.beginning_of_month(date), Date.end_of_month(date), 1)

  def period(date, :hijri_month, _week_start, corrections), do: Hijri.month(date, corrections)

  @doc """
  The whole `unit` period containing `date`, clipped to the active period:
  `nil` when `date` is outside the active period or has no such period.
  """
  @spec window(ActivePeriod.t(), Goal.period(), Date.t(), Goal.week_start(), Corrections.t()) ::
          Date.Range.t() | nil
  def window(active_period, unit, date, week_start, corrections) do
    with true <- in_active_period?(active_period, date),
         %Date.Range{} = period <- period(date, unit, week_start, corrections) do
      clip(period, active_period)
    else
      _no_window -> nil
    end
  end

  @doc "`range` clipped to the active period, or `nil` when they don't overlap."
  @spec clip(Date.Range.t(), ActivePeriod.t()) :: Date.Range.t() | nil
  def clip(%Date.Range{first: first, last: last}, %ActivePeriod{start_date: start} = period) do
    from = latest(first, start)
    to = earliest(last, last_day(period))

    if Date.after?(from, to), do: nil, else: Date.range(from, to, 1)
  end

  @doc "The days of `days` (in order) up to and including `date`."
  @spec through(Enumerable.t(Date.t()), Date.t()) :: [Date.t()]
  def through(range, date), do: Enum.take_while(range, &(not Date.after?(&1, date)))

  @doc "The day as a one-day window."
  @spec day(Date.t()) :: Date.Range.t()
  def day(date), do: Date.range(date, date, 1)

  @spec earliest(Date.t(), Date.t() | nil) :: Date.t()
  @spec earliest(nil, Date.t() | nil) :: Date.t() | nil
  def earliest(nil, other), do: other
  def earliest(date, nil), do: date
  def earliest(date, other), do: if(Date.before?(other, date), do: other, else: date)

  @spec latest(Date.t(), Date.t()) :: Date.t()
  def latest(date, other), do: if(Date.after?(other, date), do: other, else: date)

  defp after_last_day?(period, date) do
    case last_day(period) do
      nil -> false
      last -> Date.after?(date, last)
    end
  end

  defp duration_end(%ActivePeriod{duration_days: nil}), do: nil

  defp duration_end(%ActivePeriod{start_date: start, duration_days: days}),
    do: Date.add(start, days - 1)
end
