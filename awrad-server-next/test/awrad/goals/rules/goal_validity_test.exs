defmodule Awrad.Goals.Rules.GoalValidityTest do
  @moduledoc """
  contracts/goal-model/v1/fixtures/goal_validity.json, one test per case:
  goals through `Goal.new/1`, documents through `Timeline.new/1`.
  """
  use ExUnit.Case, async: true

  alias Awrad.Fixtures
  alias Awrad.Fixtures.GoalModel
  alias Awrad.Fixtures.GoalModel.Encode
  alias Awrad.Goals.Goal
  alias Awrad.Goals.Timeline

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("goal-model/v1", "goal_validity") do
    @given given
    @expect expect
    test id do
      result =
        case @given do
          %{"goal" => goal} -> goal |> GoalModel.goal_shape() |> Goal.new()
          %{"document" => document} -> document |> GoalModel.timeline_shape() |> Timeline.new()
        end

      assert Encode.validity(result) == @expect
    end
  end

  test "a missing field raises instead of building a partial goal" do
    assert_raise ArgumentError, fn -> Goal.new(%{schedule: :every_day}) end
  end

  test "a timeline without versions raises" do
    assert_raise ArgumentError, fn ->
      Timeline.new(%{
        created_on: ~D[2026-10-01],
        versions: [],
        paused: [],
        excused: [],
        ended: nil
      })
    end
  end
end
