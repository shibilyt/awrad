defmodule Awrad.Goals.Rules.GoalListPlacementTest do
  @moduledoc """
  contracts/goal-model/v1/fixtures/goal_list_placement.json, one test per
  case. Placement doesn't depend on the case's `week_start`.
  """
  use ExUnit.Case, async: true

  alias Awrad.Fixtures
  alias Awrad.Fixtures.GoalModel
  alias Awrad.Fixtures.GoalModel.Encode
  alias Awrad.Goals.Rules

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("goal-model/v1", "goal_list_placement") do
    @given given
    @expect expect
    test id do
      goals =
        for goal <- @given["goals"] do
          %{
            id: goal["id"],
            goal: GoalModel.goal_input(goal["goal"]),
            counts: GoalModel.counts(goal["counts"])
          }
        end

      placement =
        Rules.place(
          goals,
          @given["order"],
          GoalModel.date(@given["date"]),
          GoalModel.hijri_corrections(@given)
        )

      assert Encode.result(placement) == @expect
    end
  end
end
