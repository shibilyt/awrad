defmodule AwradApi.Tracking.GoalSlot do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "goal_slots" do
    field :target_count, :integer
    field :timing_type, :string, default: "anytime"
    field :timing_value, :string
    field :label, :string
    field :sort_order, :integer, default: 0
    field :deleted_at, :utc_datetime

    belongs_to :goal, AwradApi.Tracking.Goal
    has_many :count_entries, AwradApi.Tracking.CountEntry, foreign_key: :slot_id

    timestamps(type: :utc_datetime)
  end

  @timing_types ~w(anytime prayer time_window)

  def changeset(slot, attrs) do
    slot
    |> cast(attrs, [:goal_id, :target_count, :timing_type, :timing_value, :label, :sort_order, :deleted_at])
    |> validate_required([:goal_id, :target_count])
    |> validate_inclusion(:timing_type, @timing_types)
    |> validate_number(:target_count, greater_than: 0)
    |> foreign_key_constraint(:goal_id)
  end
end
