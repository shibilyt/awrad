defmodule Awrad.Repo.Migrations.CreateAudioAssets do
  @moduledoc """
  Private recordings for custom dhikrs (slice 3c, root ADR-2026-10-29,
  `contracts/audio/v1/`, server ADR 0011): one row per upload, from
  reservation to the deletion of its object.

  Unlike the other account tables, `user_id` is `ON DELETE SET NULL`: deleting
  an account leaves its rows as cleanup work, holding only the object key, so
  `Awrad.Audio.Cleaner` can still delete every object (and retry when R2
  fails) before it deletes the row.
  """

  use Ecto.Migration

  def change do
    create table(:audio_assets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      # The client's UUIDv7 for the recording, unique per account.
      add :asset_id, :uuid, null: false
      # users/<account_id>/audio/<asset_id>, kept for when user_id is gone.
      add :object_key, :text, null: false
      add :byte_size, :bigint, null: false
      add :content_type, :text, null: false
      # 64 lowercase hex digits, as declared when the upload was reserved.
      add :sha256, :text, null: false
      # pending -> ready, or either -> deleting (invisible to clients; the
      # cleanup job deletes the object, then the row).
      add :status, :text, null: false
      # When the latest signed PUT link stops working.
      add :upload_expires_at, :utc_datetime, null: false
      # When the upload was confirmed (the asset's created_at).
      add :ready_at, :utc_datetime
      # Whether an active custom dhikr of the account names it, and when that
      # last changed (or a put last named it).
      add :referenced, :boolean, null: false, default: false
      add :last_referenced_at, :utc_datetime
      # A deleting row's object may go from this time on.
      add :delete_after, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:audio_assets, [:user_id, :asset_id])
    # asset_id_in_use across accounts.
    create index(:audio_assets, [:asset_id])
    # The cleanup job's scans.
    create index(:audio_assets, [:status, :inserted_at])

    create constraint(:audio_assets, :status_known,
             check: "status IN ('pending', 'ready', 'deleting')"
           )

    create constraint(:audio_assets, :byte_size_range, check: "byte_size BETWEEN 1 AND 10000000")

    create constraint(:audio_assets, :content_type_known,
             check: "content_type IN ('audio/mpeg', 'audio/mp4')"
           )

    create constraint(:audio_assets, :ready_has_time,
             check:
               "status <> 'ready' OR (ready_at IS NOT NULL AND last_referenced_at IS NOT NULL)"
           )

    create constraint(:audio_assets, :deleting_has_time,
             check: "status <> 'deleting' OR delete_after IS NOT NULL"
           )
  end
end
