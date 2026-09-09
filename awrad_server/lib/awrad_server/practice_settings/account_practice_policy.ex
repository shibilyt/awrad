defmodule AwradServer.PracticeSettings.AccountPracticePolicy do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @day_resets ~w(midnight maghrib)
  @calculation_methods ~w(
    karachi
    north_america
    mwl
    egypt
    umm_al_qura
    moon_sighting
    dubai
    kuwait
    qatar
    singapore
  )
  @madhabs ~w(shafi hanafi)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "account_practice_policies" do
    field :day_reset, :string, default: "midnight"
    field :calculation_method, :string, default: "karachi"
    field :madhab, :string, default: "shafi"
    field :revision, :integer, default: 1

    belongs_to :user, AwradServer.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(policy, attrs) do
    policy
    |> cast(attrs, [:day_reset, :calculation_method, :madhab])
    |> validate_required([:day_reset, :calculation_method, :madhab])
    |> validate_inclusion(:day_reset, @day_resets)
    |> validate_inclusion(:calculation_method, @calculation_methods)
    |> validate_inclusion(:madhab, @madhabs)
    |> validate_number(:revision, greater_than: 0)
    |> unique_constraint(:user_id)
  end

  def day_resets, do: @day_resets
  def calculation_methods, do: @calculation_methods
  def madhabs, do: @madhabs
end
