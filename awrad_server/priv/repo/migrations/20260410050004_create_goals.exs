defmodule AwradServer.Repo.Migrations.CreateGoals do
  use Ecto.Migration

  def change do
    create table(:goals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :dhikr_id, references(:dhikrs, type: :binary_id, on_delete: :restrict), null: false
      add :frequency_type, :string, null: false, default: "daily"
      add :timing_type, :string, null: false, default: "anytime"
      add :target_type, :string, null: false, default: "fixed"
      add :duration_type, :string, null: false, default: "ongoing"
      add :config, :map, default: %{}
      add :start_date, :date, null: false
      add :end_date, :date
      add :duration_days, :integer
      add :is_active, :boolean, default: true, null: false
      add :notification_enabled, :boolean, default: false, null: false
      add :notification_time, :time
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:goals, [:user_id])
    create index(:goals, [:dhikr_id])
    create index(:goals, [:user_id, :is_active])
    create index(:goals, [:user_id, :deleted_at])
  end
end
