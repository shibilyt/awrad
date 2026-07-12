defmodule AwradApi.Repo.Migrations.HardenMobileAuthSessions do
  use Ecto.Migration

  def change do
    create table(:auth_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :device_id_hash, :binary, null: false
      add :device_name, :string, null: false
      add :platform, :string, null: false
      add :last_seen_at, :utc_datetime, null: false
      add :idle_expires_at, :utc_datetime, null: false
      add :absolute_expires_at, :utc_datetime, null: false
      add :revoked_at, :utc_datetime
      add :revoke_reason, :string
      timestamps(type: :utc_datetime)
    end

    create index(:auth_sessions, [:user_id])
    create unique_index(:auth_sessions, [:user_id, :device_id_hash])

    create table(:api_refresh_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :session_id, references(:auth_sessions, type: :binary_id, on_delete: :delete_all),
        null: false

      add :parent_id, references(:api_refresh_tokens, type: :binary_id, on_delete: :nilify_all)
      add :token_hash, :binary, null: false
      add :expires_at, :utc_datetime, null: false
      add :used_at, :utc_datetime
      add :revoked_at, :utc_datetime
      add :rotation_request_id, :binary_id
      add :retry_token_ciphertext, :binary
      add :retry_expires_at, :utc_datetime
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:api_refresh_tokens, [:token_hash])
    create index(:api_refresh_tokens, [:session_id])

    create table(:auth_rate_limits, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :scope, :string, null: false
      add :subject_hash, :binary, null: false
      add :window_started_at, :utc_datetime, null: false
      add :count, :integer, null: false, default: 1
      timestamps(type: :utc_datetime)
    end

    create unique_index(:auth_rate_limits, [:scope, :subject_hash, :window_started_at])
    create index(:auth_rate_limits, [:window_started_at])

    create table(:auth_security_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :session_id, references(:auth_sessions, type: :binary_id, on_delete: :nilify_all)
      add :event, :string, null: false
      add :subject_hash, :binary
      add :metadata, :map, null: false, default: %{}
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:auth_security_events, [:user_id, :inserted_at])
    create index(:auth_security_events, [:event, :inserted_at])
  end
end
