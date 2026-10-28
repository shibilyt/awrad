defmodule Awrad.Identity.UUIDv7LayoutTest do
  @moduledoc "contracts/identity/v1/fixtures/uuid_v7_layout.json, one test per case, through `Awrad.UUIDv7.from_parts/2`."
  use ExUnit.Case, async: true

  alias Awrad.Fixtures

  doctest Awrad.UUIDv7

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("identity/v1", "uuid_v7_layout") do
    @given given
    @expect expect
    test id do
      random = Base.decode16!(@given["random_hex"], case: :lower)
      assert %{"uuid" => Awrad.UUIDv7.from_parts(@given["unix_ms"], random)} == @expect
    end
  end

  test "generate/0 is a valid v7 ID carrying the current millisecond" do
    before = System.os_time(:millisecond)
    id = Awrad.UUIDv7.generate()
    later = System.os_time(:millisecond)

    assert Awrad.ID.valid?(id)
    assert <<unix_ms::48, 7::4, _::12, 2::2, _::62>> = Ecto.UUID.dump!(id)
    assert unix_ms in before..later
    refute Awrad.UUIDv7.generate() == id
  end

  test "from_parts/2 takes only a 48-bit time and exactly 10 random bytes" do
    assert_raise FunctionClauseError, fn -> Awrad.UUIDv7.from_parts(-1, <<0::80>>) end

    assert_raise FunctionClauseError, fn ->
      Awrad.UUIDv7.from_parts(0x1_0000_0000_0000, <<0::80>>)
    end

    assert_raise FunctionClauseError, fn -> Awrad.UUIDv7.from_parts(0, <<0::72>>) end
  end
end
