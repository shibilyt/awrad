defmodule AwradServer.Repo.Migrations.CreateDhikrTranslations do
  use Ecto.Migration

  def change do
    create table(:dhikr_translations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :dhikr_id, references(:dhikrs, type: :binary_id, on_delete: :delete_all), null: false
      add :locale, :string, null: false
      add :title, :string
      add :transliteration, :string
      add :translation, :text

      timestamps(type: :utc_datetime)
    end

    create index(:dhikr_translations, [:dhikr_id])
    create unique_index(:dhikr_translations, [:dhikr_id, :locale])
    create index(:dhikr_translations, [:locale])
  end
end
