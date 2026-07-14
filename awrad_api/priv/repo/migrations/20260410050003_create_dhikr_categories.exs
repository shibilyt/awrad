defmodule AwradApi.Repo.Migrations.CreateDhikrCategories do
  use Ecto.Migration

  def change do
    create table(:dhikr_categories, primary_key: false) do
      add :dhikr_id, references(:dhikrs, type: :binary_id, on_delete: :delete_all), null: false

      add :category_id, references(:categories, type: :binary_id, on_delete: :delete_all),
        null: false

      add :inserted_at, :utc_datetime, null: false, default: fragment("now()")
    end

    create unique_index(:dhikr_categories, [:dhikr_id, :category_id])
    create index(:dhikr_categories, [:category_id])
  end
end
