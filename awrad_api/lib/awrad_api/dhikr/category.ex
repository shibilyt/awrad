defmodule AwradApi.Dhikr.Category do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "categories" do
    field :slug, :string
    field :name_ar, :string
    field :name_en, :string
    field :sort_order, :integer, default: 0

    many_to_many :dhikrs, AwradApi.Dhikr.Dhikr, join_through: "dhikr_categories"

    timestamps(type: :utc_datetime)
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, [:slug, :name_ar, :name_en, :sort_order])
    |> validate_required([:slug, :name_ar, :name_en])
    |> unique_constraint(:slug)
  end
end
