defmodule Awrad.Goals.Rules.GoalStreakTest do
  @moduledoc "contracts/goal-model/v1/fixtures/goal_streak.json, one test per case."
  use ExUnit.Case, async: true

  alias Awrad.Fixtures
  alias Awrad.Fixtures.GoalModel
  alias Awrad.Goals.Rules

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("goal-model/v1", "goal_streak") do
    @given given
    @expect expect
    test id do
      current =
        Rules.streak(
          GoalModel.goal(@given["goal"]),
          GoalModel.counts(@given["counts"]),
          GoalModel.date(@given["date"]),
          GoalModel.week_start(@given["week_start"])
        )

      assert %{"current" => current} == @expect
    end
  end
end
