defmodule AwradServer.Tracking.CountEntry do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "count_entries" do
    field :count, :integer, default: 0
    field :date, :date

    belongs_to :user, AwradServer.Accounts.User
    belongs_to :goal, AwradServer.Tracking.Goal
    belongs_to :slot, AwradServer.Tracking.GoalSlot

    timestamps(type: :utc_datetime)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:goal_id, :slot_id, :count, :date])
    |> AwradServer.Tracking.Identity.put_client_id(attrs)
    |> validate_required([:user_id, :goal_id, :slot_id, :count, :date])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:goal_id)
    |> foreign_key_constraint(:slot_id)
    |> unique_constraint([:goal_id, :slot_id, :date])
  end

  def for_user_changeset(entry, attrs, user_id) do
    entry
    |> change(user_id: user_id)
    |> changeset(attrs)
  end
end
