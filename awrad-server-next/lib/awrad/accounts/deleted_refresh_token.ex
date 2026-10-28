defmodule Awrad.Accounts.DeletedRefreshToken do
  @moduledoc """
  What's left of a deleted account's refresh tokens (slice 3b, server ADR 0010):
  the SHA-256 of each one that could still have been used, until it would have
  expired. Nothing else is kept, not even the account ID.

  Refreshing with one answers `401 account_deleted` instead of
  `refresh_token_invalid`, so a phone can offer to remove that account's local
  profile. Only the holder of a once-valid token learns this.
  """

  use Ecto.Schema

  import Ecto.Query

  alias Awrad.Accounts.{DeviceSession, RefreshToken}
  alias Awrad.Repo

  @primary_key {:id, Awrad.UUIDv7, autogenerate: true}

  @type t :: %__MODULE__{}

  schema "deleted_account_refresh_tokens" do
    field :token_hash, :binary, redact: true
    field :expires_at, :utc_datetime

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Remembers the refresh tokens of `user_id` that still work at `now`: unused,
  not revoked, not expired, on a live session. Call it in the deletion's
  transaction, before the account's rows cascade away.
  """
  @spec remember(Ecto.UUID.t(), DateTime.t()) :: :ok
  def remember(user_id, now) do
    rows =
      from(t in RefreshToken,
        join: s in DeviceSession,
        on: s.id == t.device_session_id,
        where: s.user_id == ^user_id and is_nil(s.revoked_at),
        where: s.idle_expires_at > ^now and s.absolute_expires_at > ^now,
        where: is_nil(t.used_at) and is_nil(t.revoked_at) and t.expires_at > ^now,
        select: %{
          token_hash: t.token_hash,
          expires_at:
            type(
              fragment("LEAST(?, ?, ?)", t.expires_at, s.idle_expires_at, s.absolute_expires_at),
              :utc_datetime
            )
        }
      )
      |> Repo.all()
      |> Enum.map(&Map.merge(&1, %{id: Awrad.UUIDv7.generate(), inserted_at: now}))

    Repo.insert_all(__MODULE__, rows, on_conflict: :nothing, conflict_target: :token_hash)
    :ok
  end

  @doc "Whether `token_hash` belonged to an account deleted before it expired."
  @spec deleted?(binary(), DateTime.t()) :: boolean()
  def deleted?(token_hash, now) do
    Repo.exists?(from d in __MODULE__, where: d.token_hash == ^token_hash and d.expires_at > ^now)
  end

  @doc "Deletes the rows past their expiry. Returns how many went."
  @spec prune(DateTime.t()) :: non_neg_integer()
  def prune(now) do
    {count, _} = Repo.delete_all(from(d in __MODULE__, where: d.expires_at <= ^now))
    count
  end
end
