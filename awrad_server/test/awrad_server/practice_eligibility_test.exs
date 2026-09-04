defmodule AwradServer.PracticeEligibilityTest do
  use ExUnit.Case, async: true

  alias AwradServer.Practice.Eligibility
  alias AwradServer.Tracking.{Goal, GoalSlot}

  test "allows an active daily goal with an anytime slot on a scheduled date" do
    goal = %Goal{
      is_active: true,
      start_date: ~D[2026-07-01],
      recurrence_frequency: "daily",
      recurrence_calendar: "gregorian",
      target_policy: "per_due_date"
    }

    slot = %GoalSlot{
      is_active: true,
      slot_type: "anytime",
      timing_type: "anytime"
    }

    assert :allowed = Eligibility.evaluate(goal, slot, ~D[2026-07-16])
  end

  test "allows an advanced interval goal on its anchor cycle" do
    goal = %Goal{
      is_active: true,
      start_date: ~D[2026-07-01],
      recurrence_frequency: "interval",
      recurrence_interval_days: 3,
      recurrence_anchor_date: ~D[2026-07-01],
      recurrence_calendar: "gregorian",
      target_policy: "per_due_date"
    }

    slot = %GoalSlot{is_active: true, slot_type: "anytime", timing_type: "anytime"}

    assert :allowed = Eligibility.evaluate(goal, slot, ~D[2026-07-07])
    assert {:blocked, :off_recurrence} = Eligibility.evaluate(goal, slot, ~D[2026-07-08])
  end

  test "supports Gregorian monthly, yearly, and specific-date recurrences" do
    slot = %GoalSlot{is_active: true, slot_type: "anytime", timing_type: "anytime"}

    monthly = %Goal{
      is_active: true,
      start_date: ~D[2026-01-01],
      recurrence_frequency: "monthly",
      recurrence_calendar: "gregorian",
      recurrence_month_days: [5, 20]
    }

    assert :allowed = Eligibility.evaluate(monthly, slot, ~D[2026-07-20])
    assert {:blocked, :off_recurrence} = Eligibility.evaluate(monthly, slot, ~D[2026-07-21])

    yearly = %Goal{
      is_active: true,
      start_date: ~D[2026-01-01],
      recurrence_frequency: "yearly",
      recurrence_calendar: "gregorian",
      recurrence_month: 7,
      recurrence_month_days: [16]
    }

    assert :allowed = Eligibility.evaluate(yearly, slot, ~D[2026-07-16])
    assert {:blocked, :off_recurrence} = Eligibility.evaluate(yearly, slot, ~D[2026-08-16])

    specific_dates = %Goal{
      is_active: true,
      start_date: ~D[2026-01-01],
      recurrence_frequency: "specific_dates",
      recurrence_calendar: "gregorian",
      recurrence_specific_dates: [~D[2026-07-16]]
    }

    assert :allowed = Eligibility.evaluate(specific_dates, slot, ~D[2026-07-16])

    assert {:blocked, :off_recurrence} =
             Eligibility.evaluate(specific_dates, slot, ~D[2026-07-17])
  end

  test "marks Hijri calendar and season schedules as view-only" do
    slot = %GoalSlot{is_active: true, slot_type: "anytime", timing_type: "anytime"}

    hijri_month = %Goal{
      is_active: true,
      start_date: ~D[2026-01-01],
      recurrence_frequency: "monthly",
      recurrence_calendar: "hijri",
      recurrence_month_days: [1]
    }

    season = %Goal{
      is_active: true,
      start_date: ~D[2026-01-01],
      recurrence_frequency: "season",
      recurrence_calendar: "gregorian",
      recurrence_season_code: "ramadan"
    }

    assert {:blocked, :off_recurrence} =
             Eligibility.evaluate(hijri_month, slot, ~D[2026-07-01])

    assert {:blocked, :off_recurrence} = Eligibility.evaluate(season, slot, ~D[2026-07-01])
  end
end
