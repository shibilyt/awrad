defmodule AwradApi.Repo.Migrations.AddProgressSyncConflictRevision do
  use Ecto.Migration

  def up do
    alter table(:progress_sync_entity_conflicts) do
      add :sync_revision, :bigint
    end

    execute("""
    UPDATE progress_sync_entity_conflicts AS conflict
    SET sync_revision = entity.sync_revision
    FROM progress_sync_entities AS entity
    WHERE conflict.entity_record_id = entity.id
    """)

    alter table(:progress_sync_entity_conflicts) do
      modify :sync_revision, :bigint, null: false
    end

    create index(:progress_sync_entity_conflicts, [:user_id, :sync_revision])
  end

  def down do
    drop index(:progress_sync_entity_conflicts, [:user_id, :sync_revision])

    alter table(:progress_sync_entity_conflicts) do
      remove :sync_revision
    end
  end
end
