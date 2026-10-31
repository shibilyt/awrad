defmodule Awrad.Goals.Rules.ConsistencyTest do
  @moduledoc "contracts/goal-model/v1/fixtures/consistency.json, one test per case."
  use ExUnit.Case, async: true

  alias Awrad.Fixtures
  alias Awrad.Fixtures.GoalModel
  alias Awrad.Fixtures.GoalModel.Encode
  alias Awrad.Goals.Rules

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("goal-model/v1", "consistency") do
    @given given
    @expect expect
    test id do
      consistency =
        Rules.consistency(
          GoalModel.goal_input(@given["goal"]),
          GoalModel.counts(@given["counts"]),
          GoalModel.date(@given["date"]),
          GoalModel.week_start(@given["week_start"]),
          GoalModel.hijri_corrections(@given)
        )

      assert Encode.result(consistency) == @expect
    end
  end
end
