defmodule AwradApi.Repo.Migrations.CreateCountEntries do
  use Ecto.Migration

  def change do
    create table(:count_entries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :goal_id, references(:goals, type: :binary_id, on_delete: :delete_all), null: false
      add :slot_id, references(:goal_slots, type: :binary_id, on_delete: :nilify_all)
      add :count, :integer, default: 0, null: false
      add :date, :date, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:count_entries, [:user_id])
    create index(:count_entries, [:goal_id])
    create unique_index(:count_entries, [:goal_id, :slot_id, :date])
    create index(:count_entries, [:user_id, :date])
  end
end
