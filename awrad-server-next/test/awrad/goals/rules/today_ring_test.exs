defmodule Awrad.Goals.Rules.TodayRingTest do
  @moduledoc "contracts/goal-model/v1/fixtures/today_ring.json, one test per case."
  use ExUnit.Case, async: true

  alias Awrad.Fixtures
  alias Awrad.Fixtures.GoalModel
  alias Awrad.Fixtures.GoalModel.Encode
  alias Awrad.Goals.Rules

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("goal-model/v1", "today_ring") do
    @given given
    @expect expect
    test id do
      ring =
        Rules.today_ring(
          GoalModel.goal_input(@given["goal"]),
          GoalModel.counts(@given["counts"]),
          GoalModel.date(@given["date"]),
          GoalModel.week_start(@given["week_start"]),
          GoalModel.hijri_corrections(@given)
        )

      assert Encode.result(ring) == @expect
    end
  end
end
