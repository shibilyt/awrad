defmodule AwradApi.Dhikr.Dhikr do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "dhikrs" do
    field :catalog_key, :string
    field :is_custom, :boolean, default: false
    field :arabic, :string
    field :audio_url, :string
    field :audio_file_name, :string
    field :category, :string, default: "general"
    field :audio_count_per_play, :integer, default: 1
    field :quran_surah, :integer
    field :quran_ayah_start, :integer
    field :quran_ayah_end, :integer
    field :benefits, {:array, :string}, default: []
    field :repeat_count, :integer, default: 1
    field :sort_order, :integer, default: 0

    has_many :translations, AwradApi.Dhikr.DhikrTranslation
    many_to_many :categories, AwradApi.Dhikr.Category, join_through: "dhikr_categories"

    timestamps(type: :utc_datetime)
  end

  def changeset(dhikr, attrs) do
    dhikr
    |> cast(attrs, [
      :catalog_key,
      :is_custom,
      :arabic,
      :audio_url,
      :audio_file_name,
      :category,
      :audio_count_per_play,
      :quran_surah,
      :quran_ayah_start,
      :quran_ayah_end,
      :benefits,
      :repeat_count,
      :sort_order
    ])
    |> validate_required([:arabic])
    |> validate_length(:catalog_key, max: 100)
    |> validate_number(:audio_count_per_play, greater_than: 0)
    |> validate_number(:repeat_count, greater_than: 0)
    |> validate_number(:sort_order, greater_than_or_equal_to: 0)
    |> unique_constraint(:catalog_key)
  end
end
