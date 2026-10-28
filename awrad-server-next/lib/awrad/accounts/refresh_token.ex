defmodule Awrad.Accounts.RefreshToken do
  @moduledoc """
  One refresh token of a device session (ADR-2026-07-12, root ADR-2026-10-26).

    * The token is 32 random bytes; only its SHA-256 is stored (`token_hash`).
    * Single use: rotating sets `used_at` and creates the successor (`parent_id`
      links them).
    * The rotation's `Idempotency-Key` (`rotation_key`, unique) and the
      encrypted successor grant (`retry_ciphertext`) let a retry with the same
      key within 60 seconds (`retry_expires_at`) get the same tokens back.
  """

  use Ecto.Schema

  alias Awrad.Accounts.DeviceSession

  @primary_key {:id, Awrad.UUIDv7, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "refresh_tokens" do
    field :token_hash, :binary, redact: true
    field :expires_at, :utc_datetime
    field :used_at, :utc_datetime
    field :revoked_at, :utc_datetime
    field :rotation_key, Ecto.UUID
    field :retry_ciphertext, :binary, redact: true
    field :retry_expires_at, :utc_datetime
    belongs_to :device_session, DeviceSession
    belongs_to :parent, __MODULE__

    timestamps(type: :utc_datetime, updated_at: false)
  end
end
