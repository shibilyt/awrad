defmodule Awrad.ID do
  @moduledoc """
  Which strings are IDs (root ADR-2026-10-28,
  `contracts/identity/v1/fixtures/uuid_format.json`): lowercase hexadecimal,
  hyphenated 8-4-4-4-12, any version, but not the nil or max UUID. Nothing is
  trimmed or case-folded.

  The one check for every ID the server takes in: path parameters,
  `Idempotency-Key`, installation IDs, cursors and token claims. New IDs come
  from `Awrad.UUIDv7`.
  """

  @format ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
  @nil_uuid "00000000-0000-0000-0000-000000000000"
  @max_uuid "ffffffff-ffff-ffff-ffff-ffffffffffff"

  @doc """
  Whether `value` is an ID.

      iex> Awrad.ID.valid?("017f22e2-79b0-7cc3-98c4-dc0c0c07398f")
      true
      iex> Awrad.ID.valid?("017F22E2-79B0-7CC3-98C4-DC0C0C07398F")
      false
  """
  @spec valid?(term()) :: boolean()
  def valid?(value) when is_binary(value) and value not in [@nil_uuid, @max_uuid],
    do: Regex.match?(@format, value)

  def valid?(_value), do: false
end
