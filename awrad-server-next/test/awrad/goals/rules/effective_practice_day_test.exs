defmodule Awrad.Goals.Rules.EffectivePracticeDayTest do
  @moduledoc "contracts/goal-model/v1/fixtures/effective_practice_day.json, one test per case."
  use ExUnit.Case, async: true

  alias Awrad.Fixtures
  alias Awrad.Fixtures.GoalModel
  alias Awrad.Goals.Rules

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("goal-model/v1", "effective_practice_day") do
    @given given
    @expect expect
    test id do
      assert {:ok, date} =
               Rules.effective_practice_day(
                 GoalModel.instant(@given["instant"]),
                 @given["timezone"],
                 GoalModel.day_reset(@given["day_reset"]),
                 GoalModel.optional_instant(@given["maghrib"])
               )

      assert %{"date" => Date.to_iso8601(date)} == @expect
    end
  end

  test "an unknown time zone is an error, not a guess" do
    assert {:error, :time_zone_not_found} =
             Rules.effective_practice_day(
               ~U[2026-10-14 12:00:00Z],
               "Mars/Olympus",
               :midnight,
               nil
             )
  end
end
