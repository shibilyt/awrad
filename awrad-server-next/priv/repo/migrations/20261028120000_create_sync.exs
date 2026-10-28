defmodule Awrad.Repo.Migrations.CreateSync do
  @moduledoc """
  The change queue (slice 3b, root ADR-2026-10-28 "The change queue",
  `contracts/sync/v1/`): per account, a head revision, one entity table,
  receipts kept 90 days and merged tag IDs.

  Every table references `users` with `ON DELETE CASCADE`, so deleting an
  account deletes its synced data.
  """

  use Ecto.Migration

  def change do
    # One row per account: the revision of its last applied command. Locked
    # FOR UPDATE for a whole batch, which serializes the account's batches.
    create table(:sync_heads, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :head_revision, :bigint, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:sync_heads, [:user_id])

    # Every synced entity's latest state. A delete keeps the row as a tombstone
    # (state 'deleted', document NULL).
    create table(:sync_entities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :entity_type, :text, null: false
      add :entity_id, :uuid, null: false
      add :version, :bigint, null: false
      add :revision, :bigint, null: false
      add :state, :text, null: false
      add :document, :map

      timestamps(type: :utc_datetime)
    end

    create unique_index(:sync_entities, [:user_id, :entity_type, :entity_id])
    # The changes feed: entities after a revision, in feed order.
    create index(:sync_entities, [:user_id, :revision, :entity_type, :entity_id])

    create constraint(:sync_entities, :entity_type_known,
             check: "entity_type IN ('custom_dhikr', 'user_tag', 'dhikr_personal')"
           )

    create constraint(:sync_entities, :state_known,
             check:
               "(state = 'active' AND document IS NOT NULL) OR (state = 'deleted' AND document IS NULL)"
           )

    create constraint(:sync_entities, :version_positive, check: "version >= 1")
    create constraint(:sync_entities, :revision_positive, check: "revision >= 1")

    # Each command's first receipt, replayed for a repeat with the same payload.
    create table(:sync_receipts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :command_id, :uuid, null: false
      add :payload_hash, :binary, null: false
      add :receipt, :map, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:sync_receipts, [:user_id, :command_id])
    create index(:sync_receipts, [:inserted_at])

    # A merged tag ID (alias_id) and the tag it was merged into (tag_id).
    create table(:sync_tag_aliases, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :alias_id, :uuid, null: false
      add :tag_id, :uuid, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:sync_tag_aliases, [:user_id, :alias_id])
  end
end
