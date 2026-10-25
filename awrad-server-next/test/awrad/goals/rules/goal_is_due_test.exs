defmodule Awrad.Goals.Rules.GoalIsDueTest do
  @moduledoc "contracts/goal-model/v1/fixtures/goal_is_due.json, one test per case."
  use ExUnit.Case, async: true

  alias Awrad.Fixtures
  alias Awrad.Fixtures.GoalModel
  alias Awrad.Goals.Rules

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("goal-model/v1", "goal_is_due") do
    @given given
    @expect expect
    test id do
      due? = Rules.due?(GoalModel.goal(@given["goal"]), GoalModel.date(@given["date"]))

      assert %{"due" => due?} == @expect
    end
  end
end
