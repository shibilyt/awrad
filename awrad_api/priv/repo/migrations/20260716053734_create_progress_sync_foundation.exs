defmodule AwradApi.Repo.Migrations.CreateProgressSyncFoundation do
  use Ecto.Migration

  def change do
    create table(:progress_sync_heads, primary_key: false) do
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all),
        primary_key: true,
        null: false

      add :revision, :bigint, null: false, default: 0
      add :generation, :bigint, null: false, default: 1

      timestamps(type: :utc_datetime)
    end

    create constraint(:progress_sync_heads, :progress_sync_heads_revision_non_negative,
             check: "revision >= 0"
           )

    create constraint(:progress_sync_heads, :progress_sync_heads_generation_positive,
             check: "generation > 0"
           )

    create table(:progress_sync_actors, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :installation_id, :binary_id, null: false
      add :incarnation, :bigint, null: false
      add :next_expected_sequence, :bigint, null: false, default: 1
      add :applied_revision, :bigint, null: false, default: 0
      add :safe_compaction_revision, :bigint, null: false, default: 0
      add :lease_expires_at, :utc_datetime, null: false
      add :last_seen_at, :utc_datetime, null: false
      add :retired_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:progress_sync_actors, [:user_id])
    create index(:progress_sync_actors, [:user_id, :lease_expires_at])

    create unique_index(:progress_sync_actors, [:user_id, :installation_id, :incarnation],
             name: :progress_sync_actors_installation_incarnation_index
           )

    create constraint(:progress_sync_actors, :progress_sync_actors_incarnation_positive,
             check: "incarnation > 0"
           )

    create constraint(:progress_sync_actors, :progress_sync_actors_next_sequence_positive,
             check: "next_expected_sequence > 0"
           )

    create constraint(:progress_sync_actors, :progress_sync_actors_revisions_non_negative,
             check:
               "applied_revision >= 0 AND safe_compaction_revision >= 0 AND safe_compaction_revision <= applied_revision"
           )

    create table(:progress_sync_command_receipts, primary_key: false) do
      add :command_id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :actor_id,
          references(:progress_sync_actors, type: :binary_id, on_delete: :delete_all),
          null: false

      add :actor_sequence, :bigint, null: false
      add :canonical_payload_hash, :binary, null: false
      add :status, :string, null: false
      add :result_revision, :bigint, null: false
      add :canonical_effect, :map, null: false, default: %{}
      add :canonical_effect_hash, :binary, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:progress_sync_command_receipts, [:user_id, :result_revision])

    create unique_index(
             :progress_sync_command_receipts,
             [:user_id, :actor_id, :actor_sequence],
             name: :progress_sync_receipts_actor_sequence_index
           )

    create constraint(
             :progress_sync_command_receipts,
             :progress_sync_receipts_actor_sequence_positive,
             check: "actor_sequence > 0"
           )

    create constraint(
             :progress_sync_command_receipts,
             :progress_sync_receipts_revision_non_negative,
             check: "result_revision >= 0"
           )
  end
end
