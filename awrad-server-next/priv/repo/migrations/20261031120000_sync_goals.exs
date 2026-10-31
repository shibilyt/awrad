defmodule Awrad.Repo.Migrations.SyncGoals do
  @moduledoc """
  Goals and their order become change-queue entities (slice 4,
  `contracts/sync/v1/README.md`): `goal`, with a UUIDv7 ID, and `goal_order`,
  one per account with the account's ID as its `entity_id`. Their rows live
  in `sync_entities` like every entity's.
  """

  use Ecto.Migration

  def up do
    drop constraint(:sync_entities, :entity_type_known)

    create constraint(:sync_entities, :entity_type_known,
             check:
               "entity_type IN ('custom_dhikr', 'user_tag', 'dhikr_personal', 'practice_policy', 'goal', 'goal_order')"
           )
  end

  def down do
    drop constraint(:sync_entities, :entity_type_known)

    create constraint(:sync_entities, :entity_type_known,
             check:
               "entity_type IN ('custom_dhikr', 'user_tag', 'dhikr_personal', 'practice_policy')"
           )
  end
end
