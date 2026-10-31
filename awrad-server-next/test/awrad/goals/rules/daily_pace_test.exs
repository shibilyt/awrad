defmodule Awrad.Goals.Rules.DailyPaceTest do
  @moduledoc "contracts/goal-model/v1/fixtures/daily_pace.json, one test per case."
  use ExUnit.Case, async: true

  alias Awrad.Fixtures
  alias Awrad.Fixtures.GoalModel
  alias Awrad.Fixtures.GoalModel.Encode
  alias Awrad.Goals.Rules

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("goal-model/v1", "daily_pace") do
    @given given
    @expect expect
    test id do
      pace =
        Rules.daily_pace(
          GoalModel.goal_input(@given["goal"]),
          GoalModel.counts(@given["counts"]),
          GoalModel.date(@given["date"]),
          GoalModel.hijri_corrections(@given)
        )

      assert Encode.result(pace) == @expect
    end
  end
end
