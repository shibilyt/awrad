defmodule AwradApi.Dhikr.Dhikr do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "dhikrs" do
    field :arabic, :string
    field :audio_url, :string
    field :repeat_count, :integer, default: 1
    field :sort_order, :integer, default: 0

    has_many :translations, AwradApi.Dhikr.DhikrTranslation
    many_to_many :categories, AwradApi.Dhikr.Category, join_through: "dhikr_categories"

    timestamps(type: :utc_datetime)
  end

  def changeset(dhikr, attrs) do
    dhikr
    |> cast(attrs, [:arabic, :audio_url, :repeat_count, :sort_order])
    |> validate_required([:arabic])
    |> validate_number(:repeat_count, greater_than: 0)
    |> validate_number(:sort_order, greater_than_or_equal_to: 0)
  end
end
