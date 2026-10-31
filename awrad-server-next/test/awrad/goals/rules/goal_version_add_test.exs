defmodule Awrad.Goals.Rules.GoalVersionAddTest do
  @moduledoc "contracts/goal-model/v1/fixtures/goal_version_add.json, one test per case."
  use ExUnit.Case, async: true

  alias Awrad.Fixtures
  alias Awrad.Fixtures.GoalModel
  alias Awrad.Fixtures.GoalModel.Encode
  alias Awrad.Goals.Rules

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("goal-model/v1", "goal_version_add") do
    @given given
    @expect expect
    test id do
      versions =
        Rules.add_version(
          GoalModel.versions(@given["versions"]),
          GoalModel.date(@given["today"]),
          GoalModel.settings(@given["settings"])
        )

      assert %{"versions" => Enum.map(versions, &Encode.version/1)} == @expect
    end
  end
end
