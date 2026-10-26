defmodule Awrad.Fixtures do
  @moduledoc """
  Loads shared `awrad-fixture/1` behaviour fixtures from `contracts/`
  (`contracts/FIXTURES.md`). The fixtures are the spec: never edit one to
  match this implementation.

  Use it at compile time of a test module to generate one test per case,
  named by the case ID:

      for %{"id" => id, "given" => given, "expect" => expect} <-
            Awrad.Fixtures.cases!("goal-model/v1", "goal_is_due") do
        @given given
        @expect expect
        test id do
          ...
        end
      end

  A missing file, a file for another rule, or a file without cases raises, so
  the test run fails.
  """

  # Test support sits outside the production boundaries (Awrad, AwradWeb).
  use Boundary, top_level?: true, check: [in: false, out: false]

  @contracts Path.expand("../../../contracts", __DIR__)

  @type fixture_case :: %{required(String.t()) => term()}

  @doc ~s|The absolute path of a file under `contracts/`, e.g. `contracts_path("hijri-calendar/v1/umm-al-qura.json")`.|
  @spec contracts_path(String.t()) :: String.t()
  def contracts_path(relative), do: Path.join(@contracts, relative)

  @doc ~s|The rules with a fixture file in `contracts/<model>/fixtures/`, e.g. `rules("goal-model/v1")`.|
  @spec rules(String.t()) :: [String.t()]
  def rules(model) do
    [@contracts, model, "fixtures", "*.json"]
    |> Path.join()
    |> Path.wildcard()
    |> Enum.map(&Path.basename(&1, ".json"))
    |> Enum.sort()
  end

  @doc ~s|The cases of `contracts/<model>/fixtures/<rule>.json`, e.g. `cases!("goal-model/v1", "goal_streak")`.|
  @spec cases!(String.t(), String.t()) :: [fixture_case(), ...]
  def cases!(model, rule) do
    path = Path.join([@contracts, model, "fixtures", rule <> ".json"])

    unless File.exists?(path), do: raise("fixture file missing: #{path}")

    case path |> File.read!() |> Jason.decode!() do
      %{"format" => "awrad-fixture/1", "rule" => ^rule, "cases" => [_ | _] = cases} ->
        cases

      %{"cases" => []} ->
        raise "fixture file has no cases: #{path}"

      _other ->
        raise "not an awrad-fixture/1 file for rule #{rule}: #{path}"
    end
  end
end
