defmodule Awrad.Goals.Rules.GoalValidityTest do
  @moduledoc "contracts/goal-model/v1/fixtures/goal_validity.json, one test per case, through `Goal.new/1`."
  use ExUnit.Case, async: true

  alias Awrad.Fixtures
  alias Awrad.Fixtures.GoalModel
  alias Awrad.Goals.Goal

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("goal-model/v1", "goal_validity") do
    @given given
    @expect expect
    test id do
      result = @given["goal"] |> GoalModel.goal_shape() |> Goal.new()

      assert GoalModel.encode_validity(result) == @expect
    end
  end

  test "a missing field raises instead of building a partial goal" do
    assert_raise ArgumentError, fn -> Goal.new(%{schedule: :every_day}) end
  end
end
