defmodule AwradApi.Repo.Migrations.ExpandProgressSyncEntityTypesForDhikrTags do
  use Ecto.Migration

  def up do
    drop constraint(:progress_sync_entities, :progress_sync_entities_type_valid)

    create constraint(:progress_sync_entities, :progress_sync_entities_type_valid,
             check: "entity_type IN ('custom_dhikr', 'goal', 'user_tag', 'dhikr_tag_assignment')"
           )
  end

  def down do
    # Tag/assignment entity rows may already exist. Recreating the pre-tag CHECK
    # constraint would leave the table inconsistent, and deleting those rows is
    # a destructive data loss that this forward-only capability rollout does not
    # support. Roll back clients instead; keep the expanded entity_type set.
    raise Ecto.MigrationError,
          "expand_progress_sync_entity_types_for_dhikr_tags is irreversible once deployed"
  end
end
