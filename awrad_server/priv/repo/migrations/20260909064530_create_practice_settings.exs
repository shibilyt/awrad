defmodule AwradServer.Repo.Migrations.CreatePracticeSettings do
  use Ecto.Migration

  def change do
    create table(:account_practice_policies, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :day_reset, :string, null: false, default: "midnight"
      add :calculation_method, :string, null: false, default: "karachi"
      add :madhab, :string, null: false, default: "shafi"
      add :revision, :integer, null: false, default: 1

      timestamps(type: :utc_datetime)
    end

    create unique_index(:account_practice_policies, [:user_id])

    create constraint(:account_practice_policies, :account_practice_policies_revision_positive,
             check: "revision > 0"
           )

    create table(:practice_device_contexts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :installation_id, :binary_id, null: false
      add :timezone, :string, null: false
      add :latitude, :float
      add :longitude, :float
      add :accuracy_m, :float
      add :location_source, :string, null: false, default: "browser"
      add :revision, :integer, null: false, default: 1
      add :last_seen_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:practice_device_contexts, [:user_id])
    create unique_index(:practice_device_contexts, [:user_id, :installation_id])

    create constraint(:practice_device_contexts, :practice_device_contexts_revision_positive,
             check: "revision > 0"
           )

    create constraint(:practice_device_contexts, :practice_device_contexts_latitude_range,
             check: "latitude IS NULL OR (latitude >= -90 AND latitude <= 90)"
           )

    create constraint(:practice_device_contexts, :practice_device_contexts_longitude_range,
             check: "longitude IS NULL OR (longitude >= -180 AND longitude <= 180)"
           )

    create constraint(:practice_device_contexts, :practice_device_contexts_location_pair,
             check:
               "(latitude IS NULL AND longitude IS NULL) OR (latitude IS NOT NULL AND longitude IS NOT NULL)"
           )
  end
end
