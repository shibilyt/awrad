defmodule Awrad.Accounts.PasswordPolicyTest do
  @moduledoc """
  contracts/account-model/v1/fixtures/password_policy.json, one test per case,
  through the server's full check `PasswordPolicy.validate/1`, plus the
  server-only common-password list.
  """
  use ExUnit.Case, async: true

  alias Awrad.Accounts.{PasswordPolicy, User}
  alias Awrad.Fixtures

  doctest PasswordPolicy

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("account-model/v1", "password_policy") do
    @given given
    @expect expect
    test id do
      result =
        case PasswordPolicy.validate(@given["password"]) do
          :ok -> %{"valid" => true, "errors" => []}
          {:error, code} -> %{"valid" => false, "errors" => [Atom.to_string(code)]}
        end

      assert result == @expect
    end
  end

  describe "common passwords (server only)" do
    test "a listed password is password_too_common" do
      assert PasswordPolicy.validate("password1234") == {:error, :password_too_common}
      assert PasswordPolicy.validate("qwertyuiop123") == {:error, :password_too_common}
    end

    test "the check ignores case and compatibility forms (NFKC)" do
      assert PasswordPolicy.validate("PassWord1234") == {:error, :password_too_common}
      # Fullwidth letters and digits fold to ASCII under NFKC.
      assert PasswordPolicy.validate("ｐａｓｓｗｏｒｄ１２３４") == {:error, :password_too_common}
    end

    test "a passphrase that merely contains a listed one is fine" do
      assert PasswordPolicy.validate("my password1234 is long") == :ok
    end
  end

  test "very large input is too long without being normalised" do
    assert PasswordPolicy.validate(String.duplicate("a", 5_000)) == {:error, :password_too_long}
  end

  test "passwords are hashed in NFC, so composed and decomposed forms both verify" do
    composed = "caf\u00E9 au lait every morning"
    decomposed = "cafe\u0301 au lait every morning"
    assert composed != decomposed
    user = %User{hashed_password: User.hash(decomposed)}

    assert User.valid_password?(user, composed)
    assert User.valid_password?(user, decomposed)
    refute User.valid_password?(user, "cafe au lait every morning")
  end
end
