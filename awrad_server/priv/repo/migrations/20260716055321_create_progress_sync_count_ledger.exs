defmodule AwradServer.Repo.Migrations.CreateProgressSyncCountLedger do
  use Ecto.Migration

  def change do
    create table(:progress_sync_count_credits, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :kind, :string, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :actor_id, references(:progress_sync_actors, type: :binary_id, on_delete: :restrict)
      add :actor_sequence, :bigint
      add :goal_id, references(:goals, type: :binary_id, on_delete: :delete_all), null: false
      add :slot_id, references(:goal_slots, type: :binary_id, on_delete: :delete_all), null: false
      add :local_date, :date, null: false
      add :entity_incarnation, :bigint, null: false
      add :accepted_revision, :bigint, null: false
      add :amount, :bigint, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(
             :progress_sync_count_credits,
             [:user_id, :goal_id, :slot_id, :local_date, :entity_incarnation, :accepted_revision],
             name: :progress_sync_count_credits_bucket_revision_index
           )

    create unique_index(:progress_sync_count_credits, [:user_id, :actor_id, :actor_sequence],
             where: "kind = 'increment'",
             name: :progress_sync_count_credits_actor_sequence_index
           )

    create constraint(:progress_sync_count_credits, :progress_sync_count_credits_kind_valid,
             check: "kind IN ('increment', 'checkpoint')"
           )

    create constraint(:progress_sync_count_credits, :progress_sync_count_credits_amount_valid,
             check: "(kind = 'increment' AND amount > 0) OR (kind = 'checkpoint' AND amount >= 0)"
           )

    create constraint(:progress_sync_count_credits, :progress_sync_count_credits_revision_valid,
             check: "accepted_revision >= 0 AND entity_incarnation > 0"
           )

    create constraint(:progress_sync_count_credits, :progress_sync_count_credits_source_valid,
             check:
               "(kind = 'increment' AND actor_id IS NOT NULL AND actor_sequence > 0) OR " <>
                 "(kind = 'checkpoint' AND actor_id IS NULL AND actor_sequence IS NULL)"
           )

    create table(:progress_sync_count_consumptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :correction_command_id, :binary_id, null: false

      add :credit_id,
          references(:progress_sync_count_credits, type: :binary_id, on_delete: :restrict),
          null: false

      add :accepted_revision, :bigint, null: false
      add :amount, :bigint, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:progress_sync_count_consumptions, [:credit_id])

    create unique_index(
             :progress_sync_count_consumptions,
             [:user_id, :correction_command_id, :credit_id],
             name: :progress_sync_count_consumptions_command_credit_index
           )

    create constraint(
             :progress_sync_count_consumptions,
             :progress_sync_count_consumptions_amount_positive,
             check: "amount > 0"
           )

    create constraint(
             :progress_sync_count_consumptions,
             :progress_sync_count_consumptions_revision_non_negative,
             check: "accepted_revision >= 0"
           )

    create table(:progress_sync_count_checkpoints, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :goal_id, references(:goals, type: :binary_id, on_delete: :delete_all), null: false
      add :slot_id, references(:goal_slots, type: :binary_id, on_delete: :delete_all), null: false
      add :local_date, :date, null: false
      add :entity_incarnation, :bigint, null: false
      add :through_revision, :bigint, null: false

      add :credit_id,
          references(:progress_sync_count_credits, type: :binary_id, on_delete: :restrict),
          null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(
             :progress_sync_count_checkpoints,
             [:user_id, :goal_id, :slot_id, :local_date, :entity_incarnation],
             name: :progress_sync_count_checkpoints_bucket_index
           )

    create unique_index(:progress_sync_count_checkpoints, [:credit_id])

    create constraint(:progress_sync_count_checkpoints, :progress_sync_count_checkpoints_valid,
             check: "through_revision >= 0 AND entity_incarnation > 0"
           )

    create table(:progress_sync_count_projections, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :goal_id, references(:goals, type: :binary_id, on_delete: :delete_all), null: false
      add :slot_id, references(:goal_slots, type: :binary_id, on_delete: :delete_all), null: false
      add :local_date, :date, null: false
      add :entity_incarnation, :bigint, null: false
      add :count, :bigint, null: false, default: 0
      add :sync_revision, :bigint, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(
             :progress_sync_count_projections,
             [:user_id, :goal_id, :slot_id, :local_date, :entity_incarnation],
             name: :progress_sync_count_projections_bucket_index
           )

    create index(:progress_sync_count_projections, [:user_id, :sync_revision])

    create constraint(:progress_sync_count_projections, :progress_sync_count_projections_valid,
             check: "count >= 0 AND sync_revision >= 0 AND entity_incarnation > 0"
           )

    execute(
      """
      CREATE FUNCTION reject_progress_sync_count_ledger_update()
      RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION 'progress sync count ledger rows are immutable';
      END;
      $$ LANGUAGE plpgsql
      """,
      "DROP FUNCTION reject_progress_sync_count_ledger_update()"
    )

    execute(
      """
      CREATE TRIGGER progress_sync_count_credits_immutable
      BEFORE UPDATE ON progress_sync_count_credits
      FOR EACH ROW EXECUTE FUNCTION reject_progress_sync_count_ledger_update()
      """,
      "DROP TRIGGER progress_sync_count_credits_immutable ON progress_sync_count_credits"
    )

    execute(
      """
      CREATE TRIGGER progress_sync_count_consumptions_immutable
      BEFORE UPDATE ON progress_sync_count_consumptions
      FOR EACH ROW EXECUTE FUNCTION reject_progress_sync_count_ledger_update()
      """,
      "DROP TRIGGER progress_sync_count_consumptions_immutable ON progress_sync_count_consumptions"
    )

    execute(
      """
      CREATE FUNCTION guard_progress_sync_count_consumption_insert()
      RETURNS trigger AS $$
      DECLARE
        credit_amount bigint;
        credit_user_id uuid;
        consumed_amount numeric;
      BEGIN
        SELECT amount, user_id
        INTO credit_amount, credit_user_id
        FROM progress_sync_count_credits
        WHERE id = NEW.credit_id
        FOR UPDATE;

        IF credit_amount IS NULL OR credit_user_id <> NEW.user_id THEN
          RAISE EXCEPTION 'count consumption credit ownership mismatch'
            USING ERRCODE = '23514';
        END IF;

        SELECT COALESCE(SUM(amount), 0)
        INTO consumed_amount
        FROM progress_sync_count_consumptions
        WHERE credit_id = NEW.credit_id;

        IF consumed_amount + NEW.amount > credit_amount THEN
          RAISE EXCEPTION 'count consumption exceeds remaining credit'
            USING ERRCODE = '23514';
        END IF;

        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql
      """,
      "DROP FUNCTION guard_progress_sync_count_consumption_insert()"
    )

    execute(
      """
      CREATE TRIGGER progress_sync_count_consumptions_guard
      BEFORE INSERT ON progress_sync_count_consumptions
      FOR EACH ROW EXECUTE FUNCTION guard_progress_sync_count_consumption_insert()
      """,
      "DROP TRIGGER progress_sync_count_consumptions_guard ON progress_sync_count_consumptions"
    )
  end
end
