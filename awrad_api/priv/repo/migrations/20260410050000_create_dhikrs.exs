defmodule AwradApi.Repo.Migrations.CreateDhikrs do
  use Ecto.Migration

  def change do
    create table(:dhikrs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :arabic, :text, null: false
      add :audio_url, :string
      add :repeat_count, :integer, default: 1, null: false
      add :sort_order, :integer, default: 0, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
