defmodule Awrad.Goals.Rules.CountAttributionTest do
  @moduledoc "contracts/goal-model/v1/fixtures/count_attribution.json, one test per case."
  use ExUnit.Case, async: true

  alias Awrad.Fixtures
  alias Awrad.Fixtures.GoalModel
  alias Awrad.Fixtures.GoalModel.Encode
  alias Awrad.Goals.Rules

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("goal-model/v1", "count_attribution") do
    @given given
    @expect expect
    test id do
      goals =
        for goal <- @given["goals"] do
          %{
            id: goal["id"],
            dhikr_id: goal["dhikr_id"],
            counts: GoalModel.counts_mode(goal["counts"]),
            goal: GoalModel.goal_input(goal["goal"])
          }
        end

      attributed = Rules.attribute_counts(GoalModel.count_log(@given["log"]), goals)

      assert %{
               "goals" =>
                 Enum.map(
                   attributed,
                   &%{
                     "id" => &1.id,
                     "counts" => Enum.map(&1.counts, fn c -> Encode.count_entry(c) end)
                   }
                 )
             } == @expect
    end
  end
end
