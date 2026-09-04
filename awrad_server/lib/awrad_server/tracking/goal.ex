defmodule AwradServer.Tracking.Goal do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "goals" do
    field :target_policy, :string, default: "per_due_date"
    field :minimum_count, :integer
    field :target_count, :integer
    field :maximum_count, :integer
    field :streak_threshold, :map, default: %{"type" => "target"}
    field :reminder_threshold, :map, default: %{"type" => "target"}
    field :completion_threshold, :map, default: %{"type" => "target"}
    field :cap_behavior, :string, default: "allow_over_target"
    field :completion_policy, :string, default: "never"
    field :slot_counting_policy, :string, default: "warn_and_allow"
    field :recurrence_frequency, :string, default: "daily"
    field :recurrence_calendar, :string, default: "gregorian"
    field :recurrence_interval_days, :integer
    field :recurrence_anchor_date, :date
    field :recurrence_month, :integer
    field :recurrence_season_code, :string
    field :recurrence_weekdays, {:array, :integer}, default: []
    field :recurrence_month_days, {:array, :integer}, default: []
    field :recurrence_specific_dates, {:array, :date}, default: []
    field :completed_at, :utc_datetime

    # Legacy pre-v1 fields retained until the sync API replaces their consumers.
    field :frequency_type, :string, default: "daily"
    field :timing_type, :string, default: "anytime"
    field :target_type, :string, default: "fixed"
    field :duration_type, :string, default: "ongoing"
    field :config, :map, default: %{}
    field :start_date, :date
    field :end_date, :date
    field :duration_days, :integer
    field :is_active, :boolean, default: true
    field :notification_enabled, :boolean, default: false
    field :notification_time, :time
    field :deleted_at, :utc_datetime

    belongs_to :user, AwradServer.Accounts.User
    belongs_to :dhikr, AwradServer.Dhikr.Dhikr
    has_many :slots, AwradServer.Tracking.GoalSlot
    has_many :reminders, AwradServer.Tracking.GoalReminder
    has_many :count_entries, AwradServer.Tracking.CountEntry

    timestamps(type: :utc_datetime)
  end

  @frequency_types ~w(daily weekly monthly interval yearly)
  @timing_types ~w(anytime prayer_based time_based)
  @target_types ~w(none fixed custom)
  @duration_types ~w(ongoing fixed)
  @target_policies ~w(per_due_date cumulative_total period_total none)
  @cap_behaviors ~w(allow_over_target warn_over_target block_at_target block_at_maximum)
  @completion_policies ~w(never when_target_reached duration_ended)
  @slot_counting_policies ~w(warn_and_allow strict_active_only silent_flexible)
  @recurrence_frequencies ~w(daily weekly monthly interval yearly season specific_dates)
  @recurrence_calendars ~w(gregorian hijri)

  def changeset(goal, attrs) do
    goal
    |> cast(attrs, [
      :dhikr_id,
      :target_policy,
      :minimum_count,
      :target_count,
      :maximum_count,
      :streak_threshold,
      :reminder_threshold,
      :completion_threshold,
      :cap_behavior,
      :completion_policy,
      :slot_counting_policy,
      :recurrence_frequency,
      :recurrence_calendar,
      :recurrence_interval_days,
      :recurrence_anchor_date,
      :recurrence_month,
      :recurrence_season_code,
      :recurrence_weekdays,
      :recurrence_month_days,
      :recurrence_specific_dates,
      :completed_at,
      :frequency_type,
      :timing_type,
      :target_type,
      :duration_type,
      :config,
      :start_date,
      :end_date,
      :duration_days,
      :is_active,
      :notification_enabled,
      :notification_time,
      :deleted_at
    ])
    |> AwradServer.Tracking.Identity.put_client_id(attrs)
    |> validate_required([:user_id, :dhikr_id, :start_date])
    |> validate_inclusion(:target_policy, @target_policies)
    |> validate_inclusion(:cap_behavior, @cap_behaviors)
    |> validate_inclusion(:completion_policy, @completion_policies)
    |> validate_inclusion(:slot_counting_policy, @slot_counting_policies)
    |> validate_inclusion(:recurrence_frequency, @recurrence_frequencies)
    |> validate_inclusion(:recurrence_calendar, @recurrence_calendars)
    |> validate_inclusion(:frequency_type, @frequency_types)
    |> validate_inclusion(:timing_type, @timing_types)
    |> validate_inclusion(:target_type, @target_types)
    |> validate_inclusion(:duration_type, @duration_types)
    |> validate_number(:duration_days, greater_than: 0)
    |> validate_number(:minimum_count, greater_than: 0)
    |> validate_number(:target_count, greater_than: 0)
    |> validate_number(:maximum_count, greater_than: 0)
    |> validate_number(:recurrence_interval_days, greater_than: 0)
    |> validate_number(:recurrence_month, greater_than_or_equal_to: 1, less_than_or_equal_to: 12)
    |> validate_subset(:recurrence_weekdays, 1..7)
    |> validate_subset(:recurrence_month_days, 1..31)
    |> AwradServer.Tracking.Policy.validate_thresholds([
      :streak_threshold,
      :reminder_threshold,
      :completion_threshold
    ])
    |> AwradServer.Tracking.Policy.validate_ordered_counts()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:dhikr_id)
  end

  def for_user_changeset(goal, attrs, user_id) do
    goal
    |> change(user_id: user_id)
    |> changeset(attrs)
  end

  def soft_delete_changeset(goal) do
    change(goal, deleted_at: DateTime.utc_now(:second))
  end
end
