defmodule Awrad.Sync.PracticePolicyValidityTest do
  @moduledoc """
  contracts/practice-settings/v1/fixtures/practice_policy_validity.json, one
  test per case, through `Awrad.Sync.Documents` (what a `practice_policy` put
  is checked with).
  """
  use ExUnit.Case, async: true

  alias Awrad.Fixtures
  alias Awrad.Sync.Documents

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("practice-settings/v1", "practice_policy_validity") do
    @given given
    @expect expect
    test id do
      errors = Documents.errors("practice_policy", @given["document"])

      assert %{"valid" => errors == [], "errors" => errors} == @expect
      assert Documents.check("practice_policy", @given["document"]) == expected_check(errors)
    end
  end

  defp expected_check([]), do: :ok
  defp expected_check(errors), do: {:error, {:document_invalid, errors}}
end
