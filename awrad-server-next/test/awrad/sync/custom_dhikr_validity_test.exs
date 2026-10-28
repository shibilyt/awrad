defmodule Awrad.Sync.CustomDhikrValidityTest do
  @moduledoc """
  contracts/sync/v1/fixtures/custom_dhikr_validity.json, one test per case,
  through `Awrad.Sync.Documents.errors/2` (the check every put runs).
  """
  use ExUnit.Case, async: true

  alias Awrad.Fixtures
  alias Awrad.Sync.Documents

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("sync/v1", "custom_dhikr_validity") do
    @given given
    @expect expect
    test id do
      errors = Documents.errors("custom_dhikr", @given["document"])
      assert %{"valid" => errors == [], "errors" => errors} == @expect
    end
  end
end
