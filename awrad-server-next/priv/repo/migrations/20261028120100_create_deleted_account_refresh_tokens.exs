defmodule Awrad.Repo.Migrations.CreateDeletedAccountRefreshTokens do
  @moduledoc """
  `401 account_deleted` on refresh (slice 3b, server ADR 0010). Deleting an
  account cascades away its device sessions and refresh tokens, so a phone
  still holding one would only learn `refresh_token_invalid`. Deletion keeps
  the SHA-256 of each refresh token that could still have been used, until it
  would have expired, and nothing else: no account ID, email or device.
  """

  use Ecto.Migration

  def change do
    create table(:deleted_account_refresh_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :token_hash, :binary, null: false
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:deleted_account_refresh_tokens, [:token_hash])
    create index(:deleted_account_refresh_tokens, [:expires_at])
  end
end
