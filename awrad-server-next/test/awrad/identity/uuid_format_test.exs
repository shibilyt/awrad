defmodule Awrad.Identity.UUIDFormatTest do
  @moduledoc "contracts/identity/v1/fixtures/uuid_format.json, one test per case, through `Awrad.ID.valid?/1`."
  use ExUnit.Case, async: true

  alias Awrad.Fixtures

  doctest Awrad.ID

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("identity/v1", "uuid_format") do
    @given given
    @expect expect
    test id do
      assert %{"valid" => Awrad.ID.valid?(@given["text"])} == @expect
    end
  end

  test "non-strings and raw 16-byte binaries aren't IDs" do
    refute Awrad.ID.valid?(nil)
    refute Awrad.ID.valid?(42)
    refute Awrad.ID.valid?(Ecto.UUID.dump!(Awrad.UUIDv7.generate()))
  end
end
