defmodule AwradApi.Tracking.GoalReminder do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "goal_reminders" do
    field :reminder_type, :string
    field :hour, :integer
    field :minute, :integer
    field :offset_minutes, :integer
    field :enabled, :boolean, default: true
    field :sort_order, :integer, default: 0

    belongs_to :goal, AwradApi.Tracking.Goal
    belongs_to :slot, AwradApi.Tracking.GoalSlot

    timestamps(type: :utc_datetime)
  end

  @reminder_types ~w(fixed_time prayer_offset time_window_start)

  def changeset(reminder, attrs) do
    reminder
    |> cast(attrs, [
      :slot_id,
      :reminder_type,
      :hour,
      :minute,
      :offset_minutes,
      :enabled,
      :sort_order
    ])
    |> AwradApi.Tracking.Identity.put_client_id(attrs)
    |> validate_required([:goal_id, :reminder_type])
    |> validate_inclusion(:reminder_type, @reminder_types)
    |> validate_number(:hour, greater_than_or_equal_to: 0, less_than: 24)
    |> validate_number(:minute, greater_than_or_equal_to: 0, less_than: 60)
    |> validate_number(:sort_order, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:goal_id)
    |> foreign_key_constraint(:slot_id)
  end

  def for_goal_changeset(reminder, attrs, goal_id) do
    reminder
    |> change(goal_id: goal_id)
    |> changeset(attrs)
  end
end
