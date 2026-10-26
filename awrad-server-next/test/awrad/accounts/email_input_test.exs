defmodule Awrad.Accounts.EmailInputTest do
  @moduledoc "contracts/account-model/v1/fixtures/email_input.json, one test per case, through `EmailInput.normalize/1`."
  use ExUnit.Case, async: true

  alias Awrad.Accounts.EmailInput
  alias Awrad.Fixtures

  doctest EmailInput

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("account-model/v1", "email_input") do
    @given given
    @expect expect
    test id do
      result =
        case EmailInput.normalize(@given["input"]) do
          {:ok, email} -> %{"valid" => true, "email" => email}
          :error -> %{"valid" => false, "email" => nil}
        end

      assert result == @expect
    end
  end

  test "non-strings are invalid" do
    assert EmailInput.normalize(nil) == :error
    assert EmailInput.normalize(42) == :error
  end
end
