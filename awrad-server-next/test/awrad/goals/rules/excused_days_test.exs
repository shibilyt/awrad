defmodule Awrad.Goals.Rules.ExcusedDaysTest do
  @moduledoc "contracts/goal-model/v1/fixtures/excused_days.json, one test per case."
  use ExUnit.Case, async: true

  alias Awrad.Fixtures
  alias Awrad.Fixtures.GoalModel
  alias Awrad.Goals.Rules

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("goal-model/v1", "excused_days") do
    @given given
    @expect expect
    test id do
      goal = GoalModel.goal_input(@given["goal"])
      date = GoalModel.date(@given["date"])
      day = GoalModel.date(@given["day"])

      result =
        case @given["action"] do
          "excuse" ->
            counts = GoalModel.counts(@given["counts"])
            Rules.excuse(goal, counts, date, day, GoalModel.hijri_corrections(@given))

          "unexcuse" ->
            Rules.unexcuse(goal, date, day)
        end

      encoded =
        case result do
          :ok -> %{"allowed" => true, "reason" => nil}
          {:error, reason} -> %{"allowed" => false, "reason" => Atom.to_string(reason)}
        end

      assert encoded == @expect
    end
  end
end
