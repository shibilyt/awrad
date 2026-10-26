defmodule Awrad.Goals.Rules.DaysPerPeriodTest do
  @moduledoc "contracts/goal-model/v1/fixtures/days_per_period.json, one test per case."
  use ExUnit.Case, async: true

  alias Awrad.Fixtures
  alias Awrad.Fixtures.GoalModel
  alias Awrad.Goals.Rules

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("goal-model/v1", "days_per_period") do
    @given given
    @expect expect
    test id do
      standing =
        Rules.days_per_period(
          GoalModel.goal(@given["goal"]),
          GoalModel.counts(@given["counts"]),
          GoalModel.date(@given["date"]),
          GoalModel.week_start(@given["week_start"]),
          GoalModel.hijri_corrections(@given)
        )

      assert GoalModel.encode(standing) == @expect
    end
  end
end
