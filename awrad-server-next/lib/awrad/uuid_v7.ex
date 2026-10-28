defmodule Awrad.UUIDv7 do
  @moduledoc """
  New IDs are UUIDv7 (RFC 9562 §5.7, root ADR-2026-10-28): a 48-bit Unix
  millisecond time, then random bits, laid out as
  `contracts/identity/v1/fixtures/uuid_v7_layout.json` fixes.

  `from_parts/2` builds the ID from a time and 10 random bytes, so the shared
  fixture drives it; `generate/0` feeds it the system clock and
  `:crypto.strong_rand_bytes/1`.

  It's also the Ecto type of every schema's primary key, stored as a Postgres
  `uuid`:

      @primary_key {:id, Awrad.UUIDv7, autogenerate: true}

  Casting and loading accept any UUID (`Ecto.UUID`); only generation is v7.
  Nothing may order, expire or authorize by an ID's timestamp.
  """

  use Ecto.Type

  import Bitwise

  @type t :: String.t()

  @max_unix_ms 0xFFFF_FFFF_FFFF

  @doc "A new UUIDv7 from the system clock and a cryptographic random source."
  @spec generate() :: t()
  def generate, do: from_parts(System.os_time(:millisecond), :crypto.strong_rand_bytes(10))

  @doc """
  The UUIDv7 for `unix_ms` and the random bytes `r0..r9`: bytes 0–5 are the
  time, big-endian; byte 6 is `0x70 | (r0 & 0x0f)`; byte 7 is `r1`; byte 8 is
  `0x80 | (r2 & 0x3f)`; bytes 9–15 are `r3..r9`. Lowercase, hyphenated.

      iex> Awrad.UUIDv7.from_parts(1_645_557_742_000, Base.decode16!("0CC318C4DC0C0C07398F"))
      "017f22e2-79b0-7cc3-98c4-dc0c0c07398f"
  """
  @spec from_parts(non_neg_integer(), <<_::80>>) :: t()
  def from_parts(unix_ms, <<r0, r1, r2, rest::binary-size(7)>>)
      when is_integer(unix_ms) and unix_ms >= 0 and unix_ms <= @max_unix_ms do
    Ecto.UUID.cast!(<<unix_ms::48, 0x70 ||| (r0 &&& 0x0F), r1, 0x80 ||| (r2 &&& 0x3F)>> <> rest)
  end

  @impl Ecto.Type
  def type, do: :uuid

  @impl Ecto.Type
  def cast(value), do: Ecto.UUID.cast(value)

  @impl Ecto.Type
  def dump(value), do: Ecto.UUID.dump(value)

  @impl Ecto.Type
  def load(value), do: Ecto.UUID.load(value)

  @impl Ecto.Type
  def autogenerate, do: generate()
end
