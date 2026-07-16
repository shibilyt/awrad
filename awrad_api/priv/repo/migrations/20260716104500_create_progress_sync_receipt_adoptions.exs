defmodule AwradApi.Repo.Migrations.CreateProgressSyncReceiptAdoptions do
  use Ecto.Migration

  def change do
    create table(:progress_sync_receipt_adoptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :actor_id,
          references(:progress_sync_actors, type: :binary_id, on_delete: :delete_all),
          null: false

      add :command_id,
          references(:progress_sync_command_receipts,
            column: :command_id,
            type: :binary_id,
            on_delete: :delete_all
          ),
          null: false

      add :actor_sequence, :bigint, null: false
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(
             :progress_sync_receipt_adoptions,
             [:user_id, :actor_id, :actor_sequence],
             name: :progress_sync_adoptions_actor_sequence_index
           )

    create unique_index(
             :progress_sync_receipt_adoptions,
             [:user_id, :actor_id, :command_id],
             name: :progress_sync_adoptions_actor_command_index
           )

    create constraint(
             :progress_sync_receipt_adoptions,
             :progress_sync_adoptions_actor_sequence_positive,
             check: "actor_sequence > 0"
           )
  end
end
