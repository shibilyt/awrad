defmodule Awrad.Goals.Rules.GoalVersionOnDayTest do
  @moduledoc "contracts/goal-model/v1/fixtures/goal_version_on_day.json, one test per case."
  use ExUnit.Case, async: true

  alias Awrad.Fixtures
  alias Awrad.Fixtures.GoalModel
  alias Awrad.Fixtures.GoalModel.Encode
  alias Awrad.Goals.Rules

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("goal-model/v1", "goal_version_on_day") do
    @given given
    @expect expect
    test id do
      {version, goal} =
        Rules.version_on(GoalModel.timeline(@given["document"]), GoalModel.date(@given["date"]))

      assert %{"version" => version, "goal" => Encode.goal(goal)} == @expect
    end
  end
end
