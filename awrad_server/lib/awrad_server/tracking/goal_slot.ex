defmodule AwradServer.Tracking.GoalSlot do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "goal_slots" do
    field :minimum_count, :integer
    field :target_count, :integer
    field :maximum_count, :integer
    field :streak_threshold, :map, default: %{"type" => "target"}
    field :reminder_threshold, :map, default: %{"type" => "target"}
    field :completion_threshold, :map, default: %{"type" => "target"}
    field :cap_behavior, :string, default: "allow_over_target"
    field :slot_type, :string, default: "anytime"
    field :prayer_name, :string
    field :prayer_relation, :string
    field :start_minute, :integer
    field :end_minute, :integer
    field :start_lead_minutes_override, :integer
    field :is_active, :boolean, default: true
    field :archived_at, :utc_datetime

    # Legacy pre-v1 timing fields retained until their consumers move.
    field :timing_type, :string, default: "anytime"
    field :timing_value, :string
    field :label, :string
    field :sort_order, :integer, default: 0
    field :deleted_at, :utc_datetime

    belongs_to :goal, AwradServer.Tracking.Goal
    has_many :count_entries, AwradServer.Tracking.CountEntry, foreign_key: :slot_id

    timestamps(type: :utc_datetime)
  end

  @timing_types ~w(anytime prayer time_window)
  @slot_types ~w(anytime prayer time_window)
  @cap_behaviors ~w(allow_over_target warn_over_target block_at_target block_at_maximum)

  def changeset(slot, attrs) do
    slot
    |> cast(attrs, [
      :minimum_count,
      :target_count,
      :maximum_count,
      :streak_threshold,
      :reminder_threshold,
      :completion_threshold,
      :cap_behavior,
      :slot_type,
      :prayer_name,
      :prayer_relation,
      :start_minute,
      :end_minute,
      :start_lead_minutes_override,
      :is_active,
      :archived_at,
      :timing_type,
      :timing_value,
      :label,
      :sort_order,
      :deleted_at
    ])
    |> AwradServer.Tracking.Identity.put_client_id(attrs)
    |> validate_required([:goal_id])
    |> validate_inclusion(:slot_type, @slot_types)
    |> validate_inclusion(:cap_behavior, @cap_behaviors)
    |> validate_inclusion(:timing_type, @timing_types)
    |> validate_number(:minimum_count, greater_than: 0)
    |> validate_number(:target_count, greater_than: 0)
    |> validate_number(:maximum_count, greater_than: 0)
    |> validate_number(:start_minute, greater_than_or_equal_to: 0, less_than: 1_440)
    |> validate_number(:end_minute, greater_than_or_equal_to: 0, less_than: 1_440)
    |> validate_number(:start_lead_minutes_override, greater_than_or_equal_to: 0)
    |> validate_number(:sort_order, greater_than_or_equal_to: 0)
    |> AwradServer.Tracking.Policy.validate_thresholds([
      :streak_threshold,
      :reminder_threshold,
      :completion_threshold
    ])
    |> AwradServer.Tracking.Policy.validate_ordered_counts()
    |> foreign_key_constraint(:goal_id)
  end

  def for_goal_changeset(slot, attrs, goal_id) do
    slot
    |> change(goal_id: goal_id)
    |> changeset(attrs)
  end
end
