defmodule Awrad.Accounts.PasswordPolicy do
  @moduledoc """
  The password rule (root ADR-2026-10-26, `contracts/account-model/v1/fixtures/password_policy.json`):
  12 to 128 Unicode code points after NFC normalisation, no trimming, no
  composition rules.

  The server also rejects common passwords (`password_too_common`), from the
  compiled-in list `priv/accounts/common-passwords.txt`, compared after NFKC
  and lowercasing. Clients don't run that check.

  Passwords are hashed and verified in their NFC form (`normalize/1`), so the
  same passphrase typed on platforms that compose characters differently still
  matches.
  """

  @min 12
  @max 128
  # The API's Password schema allows 1024 code points (at most 4 bytes each); anything
  # larger is too long whatever it contains, so it isn't normalised.
  @max_bytes 1024 * 4

  @list_path Path.expand("../../../priv/accounts/common-passwords.txt", __DIR__)
  @external_resource @list_path
  @common @list_path
          |> File.read!()
          |> String.split("\n", trim: true)
          |> Enum.reject(&String.starts_with?(&1, "#"))
          |> MapSet.new()

  @type error :: :password_too_short | :password_too_long | :password_too_common

  @doc """
  Checks a new password. Returns `:ok` or `{:error, code}`.

      iex> Awrad.Accounts.PasswordPolicy.validate("dhikr every morning")
      :ok

      iex> Awrad.Accounts.PasswordPolicy.validate("short")
      {:error, :password_too_short}
  """
  @spec validate(term()) :: :ok | {:error, error()}
  def validate(password) when is_binary(password) and byte_size(password) > @max_bytes,
    do: {:error, :password_too_long}

  def validate(password) when is_binary(password) do
    with {:ok, nfc} <- nfc(password) do
      length = nfc |> String.to_charlist() |> length()

      cond do
        length < @min -> {:error, :password_too_short}
        length > @max -> {:error, :password_too_long}
        common?(nfc) -> {:error, :password_too_common}
        true -> :ok
      end
    end
  end

  def validate(_password), do: {:error, :password_too_short}

  @doc "The NFC form a password is hashed and verified in. Invalid UTF-8 is kept as is."
  @spec normalize(String.t()) :: String.t()
  def normalize(password) when is_binary(password) do
    case nfc(password) do
      {:ok, nfc} -> nfc
      {:error, _code} -> password
    end
  end

  defp nfc(password) do
    case :unicode.characters_to_nfc_binary(password) do
      nfc when is_binary(nfc) -> {:ok, nfc}
      _invalid -> {:error, :password_too_short}
    end
  end

  defp common?(nfc) do
    case :unicode.characters_to_nfkc_binary(nfc) do
      folded when is_binary(folded) -> MapSet.member?(@common, String.downcase(folded))
      _invalid -> false
    end
  end
end
