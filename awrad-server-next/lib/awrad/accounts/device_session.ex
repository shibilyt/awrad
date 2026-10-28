defmodule Awrad.Accounts.DeviceSession do
  @moduledoc """
  A mobile installation signed in to an account (`CONTEXT.md`, ADR-2026-07-12).

    * The installation ID is stored only as an HMAC (`installation_hash`).
    * Ends 30 days after the last refresh (`idle_expires_at`), 180 days after
      sign-in whatever happens (`absolute_expires_at`), or when revoked
      (`revoked_at`, `revoke_reason`).
    * At most one live session per account and installation (a partial unique
      index); signing in again from the installation replaces it.
  """

  use Ecto.Schema

  alias Awrad.Accounts.User

  @primary_key {:id, Awrad.UUIDv7, autogenerate: true}
  @foreign_key_type :binary_id

  @idle_days 30
  @absolute_days 180

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          user_id: Ecto.UUID.t() | nil,
          installation_hash: binary() | nil,
          device_name: String.t() | nil,
          platform: :android | :ios | nil,
          last_seen_at: DateTime.t() | nil,
          idle_expires_at: DateTime.t() | nil,
          absolute_expires_at: DateTime.t() | nil,
          revoked_at: DateTime.t() | nil,
          revoke_reason: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "device_sessions" do
    field :installation_hash, :binary, redact: true
    field :device_name, :string
    field :platform, Ecto.Enum, values: [:android, :ios]
    field :last_seen_at, :utc_datetime
    field :idle_expires_at, :utc_datetime
    field :absolute_expires_at, :utc_datetime
    field :revoked_at, :utc_datetime
    field :revoke_reason, :string
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc "A new session's expiry times, from sign-in time `now`."
  @spec expiries(DateTime.t()) :: %{
          idle_expires_at: DateTime.t(),
          absolute_expires_at: DateTime.t()
        }
  def expiries(now) do
    %{
      idle_expires_at: DateTime.add(now, @idle_days, :day),
      absolute_expires_at: DateTime.add(now, @absolute_days, :day)
    }
  end

  @doc "The idle expiry after a refresh at `now`, never past the absolute expiry."
  @spec next_idle_expiry(t(), DateTime.t()) :: DateTime.t()
  def next_idle_expiry(%__MODULE__{absolute_expires_at: absolute}, now) do
    idle = DateTime.add(now, @idle_days, :day)
    if DateTime.before?(idle, absolute), do: idle, else: absolute
  end

  @doc "Whether the session can still be used at `now`."
  @spec active?(t(), DateTime.t()) :: boolean()
  def active?(%__MODULE__{} = session, now) do
    is_nil(session.revoked_at) and DateTime.after?(session.idle_expires_at, now) and
      DateTime.after?(session.absolute_expires_at, now)
  end
end
