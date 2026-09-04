defmodule AwradServer.Repo.Migrations.CreateProgressSyncEntitiesAndTransfers do
  use Ecto.Migration

  def change do
    alter table(:dhikrs) do
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :deleted_at, :utc_datetime
    end

    create index(:dhikrs, [:user_id])

    create constraint(:dhikrs, :dhikrs_custom_owner_valid,
             check:
               "(is_custom = false AND user_id IS NULL) OR (is_custom = true AND user_id IS NOT NULL)"
           )

    create table(:progress_sync_entities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :entity_type, :string, null: false
      add :entity_id, :binary_id, null: false
      add :incarnation, :bigint, null: false, default: 1
      add :version, :bigint, null: false, default: 1
      add :sync_revision, :bigint, null: false
      add :document, :map
      add :state, :string, null: false, default: "active"
      add :deleted_at, :utc_datetime
      add :purge_after, :utc_datetime
      add :purged_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create unique_index(:progress_sync_entities, [:user_id, :entity_type, :entity_id],
             name: :progress_sync_entities_identity_index
           )

    create index(:progress_sync_entities, [:user_id, :sync_revision])
    create index(:progress_sync_entities, [:user_id, :state, :purge_after])

    create constraint(:progress_sync_entities, :progress_sync_entities_type_valid,
             check: "entity_type IN ('custom_dhikr', 'goal')"
           )

    create constraint(:progress_sync_entities, :progress_sync_entities_state_valid,
             check: "state IN ('active', 'deleted', 'purged')"
           )

    create constraint(:progress_sync_entities, :progress_sync_entities_versions_valid,
             check: "incarnation > 0 AND version > 0 AND sync_revision > 0"
           )

    create constraint(:progress_sync_entities, :progress_sync_entities_payload_valid,
             check:
               "(state = 'active' AND document IS NOT NULL AND deleted_at IS NULL AND purged_at IS NULL) OR " <>
                 "(state = 'deleted' AND document IS NOT NULL AND deleted_at IS NOT NULL AND purge_after IS NOT NULL AND purged_at IS NULL) OR " <>
                 "(state = 'purged' AND document IS NULL AND deleted_at IS NOT NULL AND purged_at IS NOT NULL)"
           )

    create table(:progress_sync_entity_conflicts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :entity_record_id,
          references(:progress_sync_entities, type: :binary_id, on_delete: :delete_all),
          null: false

      add :command_id, :binary_id, null: false
      add :base_version, :bigint, null: false
      add :proposed_document, :map, null: false
      add :resolved_at, :utc_datetime
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:progress_sync_entity_conflicts, [:user_id, :command_id])
    create index(:progress_sync_entity_conflicts, [:entity_record_id, :resolved_at])

    create constraint(
             :progress_sync_entity_conflicts,
             :progress_sync_entity_conflicts_version_valid,
             check: "base_version >= 0"
           )

    create table(:progress_sync_transfer_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :kind, :string, null: false
      add :from_revision, :bigint, null: false
      add :to_revision, :bigint, null: false
      add :generation, :bigint, null: false
      add :status, :string, null: false, default: "ready"
      add :page_count, :integer, null: false
      add :record_count, :integer, null: false
      add :checksum, :binary, null: false
      add :expires_at, :utc_datetime, null: false
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:progress_sync_transfer_sessions, [:user_id, :expires_at])

    create constraint(:progress_sync_transfer_sessions, :progress_sync_transfer_kind_valid,
             check: "kind IN ('snapshot', 'delta')"
           )

    create constraint(:progress_sync_transfer_sessions, :progress_sync_transfer_status_valid,
             check: "status IN ('ready', 'expired')"
           )

    create constraint(:progress_sync_transfer_sessions, :progress_sync_transfer_bounds_valid,
             check:
               "from_revision >= 0 AND to_revision >= from_revision AND generation > 0 AND page_count > 0 AND record_count >= 0"
           )

    create table(:progress_sync_transfer_pages, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :session_id,
          references(:progress_sync_transfer_sessions, type: :binary_id, on_delete: :delete_all),
          null: false

      add :page_number, :integer, null: false
      add :item_count, :integer, null: false
      add :payload, :map, null: false
      add :checksum, :binary, null: false
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:progress_sync_transfer_pages, [:session_id, :page_number])

    create constraint(:progress_sync_transfer_pages, :progress_sync_transfer_page_valid,
             check: "page_number > 0 AND item_count >= 0"
           )
  end
end
