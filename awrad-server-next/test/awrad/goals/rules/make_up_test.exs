defmodule Awrad.Goals.Rules.MakeUpTest do
  @moduledoc "contracts/goal-model/v1/fixtures/make_up.json, one test per case."
  use ExUnit.Case, async: true

  alias Awrad.Fixtures
  alias Awrad.Fixtures.GoalModel
  alias Awrad.Fixtures.GoalModel.Encode
  alias Awrad.Goals.Rules

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("goal-model/v1", "make_up") do
    @given given
    @expect expect
    test id do
      days =
        Rules.day_statuses(
          GoalModel.goal_input(@given["goal"]),
          GoalModel.counts(@given["counts"]),
          GoalModel.date(@given["from"]),
          GoalModel.date(@given["date"]),
          GoalModel.hijri_corrections(@given)
        )

      assert %{"days" => Enum.map(days, &Encode.day_status/1)} == @expect
    end
  end
end
