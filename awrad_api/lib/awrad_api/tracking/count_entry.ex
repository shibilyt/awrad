defmodule AwradApi.Tracking.CountEntry do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "count_entries" do
    field :count, :integer, default: 0
    field :date, :date

    belongs_to :user, AwradApi.Accounts.User
    belongs_to :goal, AwradApi.Tracking.Goal
    belongs_to :slot, AwradApi.Tracking.GoalSlot

    timestamps(type: :utc_datetime)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:user_id, :goal_id, :slot_id, :count, :date])
    |> validate_required([:user_id, :goal_id, :count, :date])
    |> validate_number(:count, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:goal_id)
    |> foreign_key_constraint(:slot_id)
    |> unique_constraint([:goal_id, :slot_id, :date])
  end
end
