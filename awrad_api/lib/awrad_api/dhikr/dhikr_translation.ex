defmodule AwradApi.Dhikr.DhikrTranslation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "dhikr_translations" do
    field :locale, :string
    field :title, :string
    field :transliteration, :string
    field :translation, :string

    belongs_to :dhikr, AwradApi.Dhikr.Dhikr

    timestamps(type: :utc_datetime)
  end

  def changeset(translation, attrs) do
    translation
    |> cast(attrs, [:dhikr_id, :locale, :title, :transliteration, :translation])
    |> validate_required([:dhikr_id, :locale])
    |> validate_length(:locale, min: 2, max: 10)
    |> unique_constraint([:dhikr_id, :locale])
  end
end
