defmodule AwradServer.Repo.Migrations.AddCompletedProgressSyncTransferStatus do
  use Ecto.Migration

  def up do
    drop constraint(
           :progress_sync_transfer_sessions,
           :progress_sync_transfer_status_valid
         )

    create constraint(
             :progress_sync_transfer_sessions,
             :progress_sync_transfer_status_valid,
             check: "status IN ('ready', 'completed', 'expired')"
           )
  end

  def down do
    execute(
      "UPDATE progress_sync_transfer_sessions SET status = 'ready' WHERE status = 'completed'"
    )

    drop constraint(
           :progress_sync_transfer_sessions,
           :progress_sync_transfer_status_valid
         )

    create constraint(
             :progress_sync_transfer_sessions,
             :progress_sync_transfer_status_valid,
             check: "status IN ('ready', 'expired')"
           )
  end
end
