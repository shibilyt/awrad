defmodule AwradApi.Repo.Migrations.AlignProgressModelV1 do
  use Ecto.Migration

  def up do
    alter table(:dhikrs) do
      add :catalog_key, :string
      add :is_custom, :boolean, null: false, default: false
      add :audio_file_name, :string
      add :category, :string, null: false, default: "general"
      add :audio_count_per_play, :integer, null: false, default: 1
      add :quran_surah, :integer
      add :quran_ayah_start, :integer
      add :quran_ayah_end, :integer
      add :benefits, {:array, :text}, null: false, default: []
    end

    create unique_index(:dhikrs, [:catalog_key], where: "catalog_key IS NOT NULL")

    alter table(:goals) do
      add :target_policy, :string, null: false, default: "per_due_date"
      add :minimum_count, :integer
      add :target_count, :integer
      add :maximum_count, :integer
      add :streak_threshold, :map, null: false, default: %{type: "target"}
      add :reminder_threshold, :map, null: false, default: %{type: "target"}
      add :completion_threshold, :map, null: false, default: %{type: "target"}
      add :cap_behavior, :string, null: false, default: "allow_over_target"
      add :completion_policy, :string, null: false, default: "never"
      add :slot_counting_policy, :string, null: false, default: "warn_and_allow"
      add :recurrence_frequency, :string, null: false, default: "daily"
      add :recurrence_calendar, :string, null: false, default: "gregorian"
      add :recurrence_interval_days, :integer
      add :recurrence_anchor_date, :date
      add :recurrence_month, :integer
      add :recurrence_season_code, :string
      add :recurrence_weekdays, {:array, :integer}, null: false, default: []
      add :recurrence_month_days, {:array, :integer}, null: false, default: []
      add :recurrence_specific_dates, {:array, :date}, null: false, default: []
      add :completed_at, :utc_datetime
    end

    alter table(:goal_slots) do
      modify :target_count, :integer, null: true, from: :integer
      add :minimum_count, :integer
      add :maximum_count, :integer
      add :streak_threshold, :map, null: false, default: %{type: "target"}
      add :reminder_threshold, :map, null: false, default: %{type: "target"}
      add :completion_threshold, :map, null: false, default: %{type: "target"}
      add :cap_behavior, :string, null: false, default: "allow_over_target"
      add :slot_type, :string, null: false, default: "anytime"
      add :prayer_name, :string
      add :prayer_relation, :string
      add :start_minute, :integer
      add :end_minute, :integer
      add :start_lead_minutes_override, :integer
      add :is_active, :boolean, null: false, default: true
      add :archived_at, :utc_datetime
    end

    create table(:goal_reminders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :goal_id, references(:goals, type: :binary_id, on_delete: :delete_all), null: false
      add :slot_id, references(:goal_slots, type: :binary_id, on_delete: :nilify_all)
      add :reminder_type, :string, null: false
      add :hour, :integer
      add :minute, :integer
      add :offset_minutes, :integer
      add :enabled, :boolean, null: false, default: true
      add :sort_order, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:goal_reminders, [:goal_id])
    create index(:goal_reminders, [:slot_id])

    # A pre-v1 entry without a slot cannot be assigned canonically without
    # guessing. Product data is development-only in this slice; auth tables are
    # deliberately untouched.
    execute("DELETE FROM count_entries WHERE slot_id IS NULL")

    alter table(:count_entries) do
      modify :slot_id, references(:goal_slots, type: :binary_id, on_delete: :delete_all),
        null: false,
        from: references(:goal_slots, type: :binary_id, on_delete: :nilify_all)

      modify :count, :bigint, null: false, default: 0, from: :integer
    end
  end

  def down do
    alter table(:count_entries) do
      modify :count, :integer, null: false, default: 0, from: :bigint

      modify :slot_id, references(:goal_slots, type: :binary_id, on_delete: :nilify_all),
        null: true,
        from: references(:goal_slots, type: :binary_id, on_delete: :delete_all)
    end

    drop table(:goal_reminders)

    alter table(:goal_slots) do
      modify :target_count, :integer, null: false, from: :integer
      remove :minimum_count
      remove :maximum_count
      remove :streak_threshold
      remove :reminder_threshold
      remove :completion_threshold
      remove :cap_behavior
      remove :slot_type
      remove :prayer_name
      remove :prayer_relation
      remove :start_minute
      remove :end_minute
      remove :start_lead_minutes_override
      remove :is_active
      remove :archived_at
    end

    alter table(:goals) do
      remove :target_policy
      remove :minimum_count
      remove :target_count
      remove :maximum_count
      remove :streak_threshold
      remove :reminder_threshold
      remove :completion_threshold
      remove :cap_behavior
      remove :completion_policy
      remove :slot_counting_policy
      remove :recurrence_frequency
      remove :recurrence_calendar
      remove :recurrence_interval_days
      remove :recurrence_anchor_date
      remove :recurrence_month
      remove :recurrence_season_code
      remove :recurrence_weekdays
      remove :recurrence_month_days
      remove :recurrence_specific_dates
      remove :completed_at
    end

    drop index(:dhikrs, [:catalog_key])

    alter table(:dhikrs) do
      remove :catalog_key
      remove :is_custom
      remove :audio_file_name
      remove :category
      remove :audio_count_per_play
      remove :quran_surah
      remove :quran_ayah_start
      remove :quran_ayah_end
      remove :benefits
    end
  end
end
