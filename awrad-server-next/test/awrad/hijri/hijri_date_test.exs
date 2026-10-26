defmodule Awrad.Hijri.HijriDateTest do
  @moduledoc "contracts/hijri-calendar/v1/fixtures/hijri_date.json, one test per case."
  use ExUnit.Case, async: true

  alias Awrad.Fixtures
  alias Awrad.Fixtures.HijriCalendar
  alias Awrad.Hijri
  alias Awrad.Hijri.Corrections

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("hijri-calendar/v1", "hijri_date") do
    @given given
    @expect expect
    test id do
      date =
        Hijri.date(
          Date.from_iso8601!(@given["date"]),
          HijriCalendar.corrections!(@given["corrections"])
        )

      assert HijriCalendar.encode_date(date) == @expect
    end
  end

  describe "month/2 and days/1" do
    test "a month's Gregorian days follow its corrected start" do
      {:ok, corrections} = Corrections.new([%{year: 1447, month: 9, offset_days: 1}])

      assert Hijri.month(~D[2026-03-01], Corrections.none()) ==
               Date.range(~D[2026-02-18], ~D[2026-03-19])

      assert Hijri.month(~D[2026-03-01], corrections) ==
               Date.range(~D[2026-02-19], ~D[2026-03-20])
    end

    test "outside the table there's no month" do
      assert Hijri.month(~D[1979-11-20], Corrections.none()) == nil
      assert Hijri.month(~D[2077-11-17], Corrections.none()) == nil
    end

    test "the table's days move with the first and last corrections" do
      assert Hijri.days(Corrections.none()) == Date.range(~D[1979-11-21], ~D[2077-11-16])

      {:ok, corrections} =
        Corrections.new([
          %{year: 1400, month: 1, offset_days: -1},
          %{year: 1500, month: 12, offset_days: -1}
        ])

      assert Hijri.days(corrections) == Date.range(~D[1979-11-20], ~D[2077-11-15])
    end
  end
end
