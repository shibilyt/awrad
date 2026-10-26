defmodule Awrad.SharedFixturesTest do
  @moduledoc """
  The server runs every shared rule file, and its copy of the Hijri table is
  the contracts one.
  """
  use ExUnit.Case, async: true

  alias Awrad.Fixtures

  # Each model's fixture files and the directory of their runners: one
  # `<rule>_test.exs` per `<rule>.json`, loading that file.
  @runners %{
    "goal-model/v1" => "test/awrad/goals/rules",
    "hijri-calendar/v1" => "test/awrad/hijri"
  }

  for {model, dir} <- @runners do
    @model model
    @dir dir
    test "every #{model} rule file has a runner" do
      rules = Fixtures.rules(@model)
      assert rules != []

      for rule <- rules do
        runner = Path.join(@dir, rule <> "_test.exs")
        assert File.exists?(runner), "no runner for #{@model}/fixtures/#{rule}.json: #{runner}"

        assert File.read!(runner) =~ ~s|Fixtures.cases!("#{@model}", "#{rule}")|,
               "#{runner} doesn't load #{@model}/fixtures/#{rule}.json"
      end
    end
  end

  # The release compiles the table from priv/ (Awrad.Hijri.Table) and never
  # reads contracts/, so this copy must stay identical to the contracts file.
  test "the server's Hijri table is the contracts one" do
    copy = Path.expand("priv/hijri-calendar/umm-al-qura.json")
    source = Fixtures.contracts_path("hijri-calendar/v1/umm-al-qura.json")

    assert File.read!(copy) == File.read!(source), """
    #{copy} differs from #{source}. Refresh the server's copy:

        cp ../contracts/hijri-calendar/v1/umm-al-qura.json priv/hijri-calendar/
    """
  end
end
