defmodule Awrad.Repo.Migrations.SyncPracticePolicy do
  @moduledoc """
  The account practice policy becomes a change-queue entity (slice 3d, root
  ADR-2026-10-29): `practice_policy`, one per account, with the account's ID
  as its `entity_id`. Its row lives in `sync_entities` like every entity's,
  so deleting the account deletes it (`ON DELETE CASCADE`).
  """

  use Ecto.Migration

  def up do
    drop constraint(:sync_entities, :entity_type_known)

    create constraint(:sync_entities, :entity_type_known,
             check:
               "entity_type IN ('custom_dhikr', 'user_tag', 'dhikr_personal', 'practice_policy')"
           )
  end

  def down do
    drop constraint(:sync_entities, :entity_type_known)

    create constraint(:sync_entities, :entity_type_known,
             check: "entity_type IN ('custom_dhikr', 'user_tag', 'dhikr_personal')"
           )
  end
end
