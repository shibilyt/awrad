defmodule AwradApi.Repo.Migrations.CreateCategories do
  use Ecto.Migration

  def change do
    create table(:categories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :slug, :string, null: false
      add :name_ar, :string, null: false
      add :name_en, :string, null: false
      add :sort_order, :integer, default: 0, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:categories, [:slug])
  end
end
