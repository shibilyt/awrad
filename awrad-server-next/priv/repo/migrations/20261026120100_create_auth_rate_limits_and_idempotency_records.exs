defmodule Awrad.Repo.Migrations.CreateAuthRateLimitsAndIdempotencyRecords do
  @moduledoc """
  Fixed-window rate limits for account actions (server ADR 0006) and stored
  `Idempotency-Key` results (server ADR 0007).
  """

  use Ecto.Migration

  def change do
    create table(:auth_rate_limits, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :scope, :string, null: false
      add :subject_hash, :binary, null: false
      add :window_started_at, :utc_datetime, null: false
      add :count, :integer, null: false, default: 1

      add :updated_at, :utc_datetime, null: false
    end

    create unique_index(:auth_rate_limits, [:scope, :subject_hash, :window_started_at])
    create index(:auth_rate_limits, [:window_started_at])

    create table(:idempotency_records, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :scope, :string, null: false
      add :key, :uuid, null: false
      add :fingerprint, :binary, null: false
      add :status, :integer, null: false
      add :content_type, :string
      add :body_ciphertext, :binary
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:idempotency_records, [:scope, :key])
    create index(:idempotency_records, [:expires_at])
  end
end
