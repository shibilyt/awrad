defmodule AwradApi.Repo.Migrations.CreateGoalSlots do
  use Ecto.Migration

  def change do
    create table(:goal_slots, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :goal_id, references(:goals, type: :binary_id, on_delete: :delete_all), null: false
      add :target_count, :integer, null: false
      add :timing_type, :string, null: false, default: "anytime"
      add :timing_value, :string
      add :label, :string
      add :sort_order, :integer, default: 0, null: false
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:goal_slots, [:goal_id])
  end
end
