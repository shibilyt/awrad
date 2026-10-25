defmodule Awrad.Goals.Rules.GoalCompletionTest do
  @moduledoc "contracts/goal-model/v1/fixtures/goal_completion.json, one test per case."
  use ExUnit.Case, async: true

  alias Awrad.Fixtures
  alias Awrad.Fixtures.GoalModel
  alias Awrad.Goals.Rules

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("goal-model/v1", "goal_completion") do
    @given given
    @expect expect
    test id do
      completed? =
        Rules.completed?(
          GoalModel.goal(@given["goal"]),
          GoalModel.counts(@given["counts"]),
          GoalModel.date(@given["date"])
        )

      assert %{"completed" => completed?} == @expect
    end
  end
end
