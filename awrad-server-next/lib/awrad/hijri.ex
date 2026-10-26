defmodule Awrad.Hijri do
  @moduledoc """
  The Hijri calendar for rules (slice 1b; root ADR-2026-10-26): the shared
  Umm al-Qura table (`contracts/hijri-calendar/v1/umm-al-qura.json`, 1400–1500
  AH) with the account's month-start corrections (`Awrad.Hijri.Corrections`).
  No Hijri library.

  The shared fixtures in `contracts/hijri-calendar/v1/fixtures/` are the spec.
  Outside the table there's no Hijri date, so `date/2` and `month/2` return
  `nil` there.

  The input is an effective practice day, so with the Maghrib reset the Hijri
  date changes at Maghrib.
  """

  use Boundary, deps: [], exports: [Corrections, HijriDate]

  alias Awrad.Hijri.Corrections
  alias Awrad.Hijri.HijriDate
  alias Awrad.Hijri.Table

  @doc """
  The Hijri date of `date` and its month's length, or `nil` outside the
  (adjusted) table (fixtures/hijri_date.json).
  """
  @spec date(Date.t(), Corrections.t()) :: HijriDate.t() | nil
  def date(date, %Corrections{} = corrections) do
    day = Date.to_gregorian_days(date)

    with index when is_integer(index) <- month_index(day, corrections) do
      {year, month} = Table.year_month(index)
      first = Corrections.start(corrections, index)
      next = Corrections.start(corrections, index + 1)

      %HijriDate{year: year, month: month, day: day - first + 1, month_length: next - first}
    end
  end

  @doc "The Gregorian days of the (adjusted) Hijri month containing `date`, or `nil` outside the table."
  @spec month(Date.t(), Corrections.t()) :: Date.Range.t() | nil
  def month(date, %Corrections{} = corrections) do
    with index when is_integer(index) <- month_index(Date.to_gregorian_days(date), corrections) do
      days_between(
        Corrections.start(corrections, index),
        Corrections.start(corrections, index + 1)
      )
    end
  end

  @doc "Every day the (adjusted) table covers: 1 Muharram 1400 to the end of Dhu al-Hijjah 1500."
  @spec days(Corrections.t()) :: Date.Range.t()
  def days(%Corrections{} = corrections) do
    days_between(
      Corrections.start(corrections, 0),
      Corrections.start(corrections, Table.months())
    )
  end

  defp days_between(first, next),
    do: Date.range(Date.from_gregorian_days(first), Date.from_gregorian_days(next - 1), 1)

  # A correction moves a month's start by at most 2 days and every month keeps
  # 29 or 30 days, so the adjusted month containing `day` is the table's
  # month for it or one of its neighbours.
  defp month_index(day, corrections) do
    floor = Table.floor_index(day)

    Enum.find(max(floor - 1, 0)..min(floor + 1, Table.months() - 1)//1, fn index ->
      Corrections.start(corrections, index) <= day and
        day < Corrections.start(corrections, index + 1)
    end)
  end
end
