defmodule AwradApi.Tracking.ProgressModelV1Test do
  use ExUnit.Case, async: true

  alias AwradApi.Dhikr.BuiltInRegistry
  alias AwradApi.Tracking.{CountEntry, Goal, GoalReminder, GoalSlot}

  @uuid_v1 "6ba7b810-9dad-11d1-80b4-00c04fd430c8"

  test "the API registry matches the shared 113 UUID/catalog identities" do
    contract =
      Path.expand("../../../../contracts/progress-model/v1/builtin-dhikrs.json", __DIR__)
      |> File.read!()
      |> Jason.decode!()

    expected = MapSet.new(contract["dhikrs"], &{&1["catalog_key"], &1["id"]})
    actual = MapSet.new(BuiltInRegistry.all(), &{&1.catalog_key, &1.id})

    assert MapSet.size(actual) == 113
    assert actual == expected

    asma_ul_husna =
      BuiltInRegistry.all()
      |> Enum.filter(&String.starts_with?(&1.catalog_key, "asma-ul-husna-"))

    assert length(asma_ul_husna) == 100
    assert Enum.map(asma_ul_husna, & &1.sort_order) == Enum.to_list(1..100)
    assert hd(asma_ul_husna).arabic == "يَا ٱللَّٰهُ"
    assert Enum.all?(asma_ul_husna, &(&1.category == "asma_ul_husna"))
    assert Enum.all?(asma_ul_husna, &(Map.get(&1, :audio_url) == nil))
  end

  test "progress changesets accept client UUIDv4 values and reject other UUID versions" do
    user_id = Ecto.UUID.generate()
    dhikr_id = Ecto.UUID.generate()
    goal_id = Ecto.UUID.generate()
    slot_id = Ecto.UUID.generate()

    goal_attrs = %{id: goal_id, dhikr_id: dhikr_id, start_date: ~D[2026-07-13]}

    assert %{valid?: true, changes: %{id: ^goal_id}} =
             Goal.for_user_changeset(%Goal{}, goal_attrs, user_id)

    refute Goal.for_user_changeset(%Goal{}, %{goal_attrs | id: @uuid_v1}, user_id).valid?

    assert %{valid?: true, changes: %{id: ^slot_id, goal_id: ^goal_id}} =
             GoalSlot.for_goal_changeset(%GoalSlot{}, %{id: slot_id, target_count: 100}, goal_id)

    reminder_id = Ecto.UUID.generate()

    assert %{valid?: true, changes: %{id: ^reminder_id, goal_id: ^goal_id}} =
             GoalReminder.for_goal_changeset(
               %GoalReminder{},
               %{
                 id: reminder_id,
                 slot_id: slot_id,
                 reminder_type: "fixed_time",
                 hour: 8,
                 minute: 0
               },
               goal_id
             )

    entry_id = Ecto.UUID.generate()

    assert %{valid?: true, changes: %{id: ^entry_id, count: 9_007_199_254_740_993}} =
             CountEntry.for_user_changeset(
               %CountEntry{},
               %{
                 id: entry_id,
                 goal_id: goal_id,
                 slot_id: slot_id,
                 count: 9_007_199_254_740_993,
                 date: ~D[2026-07-13]
               },
               user_id
             )
  end

  test "canonical ownership and threshold validation is enforced" do
    goal_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()

    refute CountEntry.for_user_changeset(
             %CountEntry{},
             %{goal_id: goal_id, count: 1, date: ~D[2026-07-13]},
             user_id
           ).valid?

    changeset =
      Goal.for_user_changeset(
        %Goal{},
        %{
          dhikr_id: Ecto.UUID.generate(),
          start_date: ~D[2026-07-13],
          streak_threshold: %{"type" => "custom", "count" => 0}
        },
        user_id
      )

    assert "must select any_positive, minimum, target, maximum, or custom(count)" in errors_on(
             changeset
           ).streak_threshold
  end

  test "API defaults match progress-model v1 defaults" do
    goal = %Goal{}
    slot = %GoalSlot{}
    reminder = %GoalReminder{}

    assert goal.target_policy == "per_due_date"
    assert goal.completion_policy == "never"
    assert goal.slot_counting_policy == "warn_and_allow"
    assert goal.recurrence_frequency == "daily"
    assert goal.recurrence_calendar == "gregorian"
    assert goal.cap_behavior == "allow_over_target"
    assert slot.slot_type == "anytime"
    assert slot.is_active
    assert reminder.enabled
    assert reminder.sort_order == 0
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, _options} -> message end)
  end
end
