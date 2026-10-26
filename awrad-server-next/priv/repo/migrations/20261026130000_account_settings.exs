defmodule Awrad.Repo.Migrations.AccountSettings do
  @moduledoc """
  Account settings (slice 2b):

    * browser session tokens get a name ("Firefox on Windows"), `last_seen_at`,
      and the token they replaced on reissue, accepted for a short grace;
    * email codes can carry the new address of an email change;
    * stored idempotency results belong to the account that made them, so they
      are per account and go when the account is deleted.
  """

  use Ecto.Migration

  def up do
    alter table(:users_tokens) do
      add :name, :string, size: 120
      add :last_seen_at, :utc_datetime
      add :previous_token, :binary
      add :previous_token_valid_until, :utc_datetime
    end

    execute "UPDATE users_tokens SET last_seen_at = inserted_at"

    alter table(:users_tokens) do
      modify :last_seen_at, :utc_datetime, null: false
    end

    create unique_index(:users_tokens, [:previous_token], where: "previous_token IS NOT NULL")

    alter table(:email_codes) do
      add :new_email, :citext
    end

    alter table(:idempotency_records) do
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
    end

    drop unique_index(:idempotency_records, [:scope, :key])
    create unique_index(:idempotency_records, [:scope, :key, :user_id], nulls_distinct: false)
    create index(:idempotency_records, [:user_id])
  end

  def down do
    drop index(:idempotency_records, [:user_id])
    drop unique_index(:idempotency_records, [:scope, :key, :user_id])
    execute "DELETE FROM idempotency_records WHERE user_id IS NOT NULL"
    create unique_index(:idempotency_records, [:scope, :key])

    alter table(:idempotency_records) do
      remove :user_id
    end

    alter table(:email_codes) do
      remove :new_email
    end

    drop unique_index(:users_tokens, [:previous_token])

    alter table(:users_tokens) do
      remove :name
      remove :last_seen_at
      remove :previous_token
      remove :previous_token_valid_until
    end
  end
end
