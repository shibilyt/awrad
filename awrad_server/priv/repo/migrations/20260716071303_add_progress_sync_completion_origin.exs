defmodule AwradServer.Repo.Migrations.AddProgressSyncCompletionOrigin do
  use Ecto.Migration

  def change do
    alter table(:progress_sync_entities) do
      add :completion_origin, :string
    end

    create constraint(:progress_sync_entities, :progress_sync_entities_completion_origin_valid,
             check:
               "completion_origin IS NULL OR completion_origin IN ('manual', 'automatic', 'duration')"
           )
  end
end
