defmodule AwradApi.Tracking.Goal do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "goals" do
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

    belongs_to :user, AwradApi.Accounts.User
    belongs_to :dhikr, AwradApi.Dhikr.Dhikr
    has_many :slots, AwradApi.Tracking.GoalSlot
    has_many :count_entries, AwradApi.Tracking.CountEntry

    timestamps(type: :utc_datetime)
  end

  @frequency_types ~w(daily weekly monthly interval yearly)
  @timing_types ~w(anytime prayer_based time_based)
  @target_types ~w(none fixed custom)
  @duration_types ~w(ongoing fixed)

  def changeset(goal, attrs) do
    goal
    |> cast(attrs, [
      :user_id, :dhikr_id, :frequency_type, :timing_type, :target_type,
      :duration_type, :config, :start_date, :end_date, :duration_days,
      :is_active, :notification_enabled, :notification_time, :deleted_at
    ])
    |> validate_required([:user_id, :dhikr_id, :start_date])
    |> validate_inclusion(:frequency_type, @frequency_types)
    |> validate_inclusion(:timing_type, @timing_types)
    |> validate_inclusion(:target_type, @target_types)
    |> validate_inclusion(:duration_type, @duration_types)
    |> validate_number(:duration_days, greater_than: 0)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:dhikr_id)
  end

  def soft_delete_changeset(goal) do
    change(goal, deleted_at: DateTime.utc_now(:second))
  end
end
