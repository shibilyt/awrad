defmodule AwradServer.WebSyncTest do
  use AwradServer.DataCase, async: true

  import Ecto.Query

  alias AwradServer.Dhikr.Dhikr
  alias AwradServer.PracticeSettings.DeviceContext
  alias AwradServer.PracticeSettings
  alias AwradServer.ProgressSync
  alias AwradServer.ProgressSync.{Actor, CountCredit, CountProjection, EntityRecord}
  alias AwradServer.Tracking
  alias AwradServer.WebSync

  import AwradServer.AccountsFixtures

  test "increments through a browser actor with a server allocated sequence" do
    scope = user_scope_fixture()
    {goal, slot} = create_bucket(scope)
    installation_id = Ecto.UUID.generate()
    command_id = Ecto.UUID.generate()

    assert {:ok,
            %{
              status: :accepted,
              revision: 1,
              effect: %{"applied_amount" => "1", "count" => "1"}
            }} =
             WebSync.increment(scope, installation_id, %{
               command_id: command_id,
               goal_id: goal.id,
               slot_id: slot.id,
               local_date: ~D[2026-07-16],
               timezone: "Asia/Kolkata"
             })

    assert %Actor{
             user_id: user_id,
             installation_id: ^installation_id,
             next_expected_sequence: 2,
             applied_revision: 1,
             safe_compaction_revision: 1
           } = Repo.one!(from actor in Actor, where: actor.user_id == ^scope.user.id)

    assert user_id == scope.user.id
    assert Repo.aggregate(CountCredit, :count) == 1

    assert %DeviceContext{
             timezone: "Asia/Kolkata",
             latitude: nil,
             longitude: nil,
             location_source: "browser"
           } =
             Repo.one!(
               from context in DeviceContext,
                 where:
                   context.user_id == ^scope.user.id and
                     context.installation_id == ^installation_id
             )

    assert %CountProjection{count: 1} =
             Repo.one!(
               from projection in CountProjection,
                 where:
                   projection.user_id == ^scope.user.id and
                     projection.goal_id == ^goal.id and projection.slot_id == ^slot.id and
                     projection.local_date == ^~D[2026-07-16]
             )
  end

  test "replaying a browser command id does not create a second credit" do
    scope = user_scope_fixture()
    {goal, slot} = create_bucket(scope)
    installation_id = Ecto.UUID.generate()
    command_id = Ecto.UUID.generate()
    attrs = increment_attrs(command_id, goal.id, slot.id)

    assert {:ok, %{status: :accepted, revision: 1}} =
             WebSync.increment(scope, installation_id, attrs)

    assert {:ok, %{status: :duplicate, revision: 1}} =
             WebSync.increment(scope, installation_id, attrs)

    assert Repo.aggregate(CountCredit, :count) == 1
  end

  test "the same browser installation is isolated when the account changes" do
    first_scope = user_scope_fixture()
    second_scope = user_scope_fixture()
    {first_goal, first_slot} = create_bucket(first_scope)
    {second_goal, second_slot} = create_bucket(second_scope)
    installation_id = Ecto.UUID.generate()

    assert {:ok, %{status: :accepted}} =
             WebSync.increment(
               first_scope,
               installation_id,
               increment_attrs(Ecto.UUID.generate(), first_goal.id, first_slot.id)
             )

    assert {:ok, %{status: :accepted}} =
             WebSync.increment(
               second_scope,
               installation_id,
               increment_attrs(Ecto.UUID.generate(), second_goal.id, second_slot.id)
             )

    assert Repo.aggregate(CountCredit, :count) == 2

    assert Repo.aggregate(
             from(credit in CountCredit, where: credit.user_id == ^first_scope.user.id),
             :count
           ) == 1

    assert Repo.aggregate(
             from(credit in CountCredit, where: credit.user_id == ^second_scope.user.id),
             :count
           ) == 1

    assert Repo.aggregate(
             from(actor in Actor, where: actor.installation_id == ^installation_id),
             :count
           ) ==
             2
  end

  test "rejects a browser count when the goal is off its recurrence" do
    scope = user_scope_fixture()
    {goal, slot} = create_bucket(scope)

    goal
    |> Ecto.Changeset.change(recurrence_frequency: "weekly", recurrence_weekdays: [1])
    |> Repo.update!()

    assert {:error, :off_recurrence} =
             WebSync.increment(
               scope,
               Ecto.UUID.generate(),
               increment_attrs(Ecto.UUID.generate(), goal.id, slot.id)
             )

    assert Repo.aggregate(CountCredit, :count) == 0
    assert Repo.aggregate(Actor, :count) == 0
  end

  test "rejects browser counts for unverified accounts" do
    scope = user_scope_fixture(unconfirmed_user_fixture())

    assert {:error, :email_not_verified} =
             WebSync.increment(scope, Ecto.UUID.generate(), %{})

    assert Repo.aggregate(Actor, :count) == 0
  end

  test "rejects a browser count at a canonical slot cap" do
    scope = user_scope_fixture()
    {goal, slot} = create_bucket(scope)

    slot
    |> Ecto.Changeset.change(target_count: 1, cap_behavior: "block_at_target")
    |> Repo.update!()

    assert {:ok, %{status: :accepted}} =
             WebSync.increment(
               scope,
               Ecto.UUID.generate(),
               increment_attrs(Ecto.UUID.generate(), goal.id, slot.id)
             )

    assert {:error, :count_cap_reached} =
             WebSync.increment(
               scope,
               Ecto.UUID.generate(),
               increment_attrs(Ecto.UUID.generate(), goal.id, slot.id)
             )

    assert Repo.aggregate(CountCredit, :count) == 1
  end

  test "derives the canonical count date after the browser Maghrib boundary" do
    scope = user_scope_fixture()
    {goal, slot} = create_bucket(scope)
    assert {:ok, _policy} = PracticeSettings.update_policy(scope, %{day_reset: "maghrib"})

    installation_id = Ecto.UUID.generate()
    civil_date = ~D[2026-07-16]
    effective_date = Date.add(civil_date, 1)
    maghrib_at = DateTime.add(DateTime.utc_now(:second), -60, :second)

    assert {:ok, _context} =
             PracticeSettings.upsert_device_context(scope, installation_id, %{
               timezone: "Asia/Kolkata",
               latitude: 12.9716,
               longitude: 77.5946,
               location_source: "manual"
             })

    assert {:ok, %{status: :accepted}} =
             WebSync.increment(
               scope,
               installation_id,
               increment_attrs(Ecto.UUID.generate(), goal.id, slot.id)
               |> Map.merge(%{
                 civil_date: civil_date,
                 local_date: effective_date,
                 maghrib_at: DateTime.to_iso8601(maghrib_at)
               })
             )

    assert %CountProjection{local_date: ^effective_date, count: 1} =
             Repo.one!(
               from projection in CountProjection,
                 where:
                   projection.user_id == ^scope.user.id and
                     projection.goal_id == ^goal.id and projection.slot_id == ^slot.id
             )
  end

  test "rejects a browser count whose date disagrees with the Maghrib boundary" do
    scope = user_scope_fixture()
    {goal, slot} = create_bucket(scope)
    assert {:ok, _policy} = PracticeSettings.update_policy(scope, %{day_reset: "maghrib"})

    civil_date = ~D[2026-07-16]
    maghrib_at = DateTime.add(DateTime.utc_now(:second), -60, :second)

    assert {:error, :practice_date_mismatch} =
             WebSync.increment(
               scope,
               Ecto.UUID.generate(),
               increment_attrs(Ecto.UUID.generate(), goal.id, slot.id)
               |> Map.merge(%{
                 civil_date: civil_date,
                 local_date: Date.add(civil_date, 2),
                 maghrib_at: DateTime.to_iso8601(maghrib_at)
               })
             )

    assert Repo.aggregate(CountCredit, :count) == 0
  end

  test "falls back to the civil date when Maghrib has no device location" do
    scope = user_scope_fixture()
    {goal, slot} = create_bucket(scope)
    assert {:ok, _policy} = PracticeSettings.update_policy(scope, %{day_reset: "maghrib"})

    civil_date = ~D[2026-07-16]
    maghrib_at = DateTime.add(DateTime.utc_now(:second), -60, :second)

    assert {:ok, %{status: :accepted}} =
             WebSync.increment(
               scope,
               Ecto.UUID.generate(),
               increment_attrs(Ecto.UUID.generate(), goal.id, slot.id)
               |> Map.merge(%{
                 civil_date: civil_date,
                 local_date: civil_date,
                 maghrib_at: DateTime.to_iso8601(maghrib_at)
               })
             )

    assert %CountProjection{local_date: ^civil_date, count: 1} =
             Repo.one!(
               from projection in CountProjection,
                 where:
                   projection.user_id == ^scope.user.id and
                     projection.goal_id == ^goal.id and projection.slot_id == ^slot.id
             )
  end

  test "rolls an expired browser actor to a new incarnation" do
    scope = user_scope_fixture()
    {goal, slot} = create_bucket(scope)
    installation_id = Ecto.UUID.generate()

    assert {:ok, %{status: :accepted}} =
             WebSync.increment(
               scope,
               installation_id,
               increment_attrs(Ecto.UUID.generate(), goal.id, slot.id)
             )

    actor = Repo.one!(from actor in Actor, where: actor.user_id == ^scope.user.id)

    actor
    |> Ecto.Changeset.change(
      lease_expires_at: DateTime.add(DateTime.utc_now(:second), -1, :second)
    )
    |> Repo.update!()

    assert {:ok, %{status: :accepted}} =
             WebSync.increment(
               scope,
               installation_id,
               increment_attrs(Ecto.UUID.generate(), goal.id, slot.id)
             )

    assert [%Actor{incarnation: 1}, %Actor{incarnation: 2}] =
             Repo.all(
               from actor in Actor,
                 where: actor.user_id == ^scope.user.id,
                 order_by: :incarnation
             )
  end

  test "acknowledges a browser actor at the current canonical head" do
    scope = user_scope_fixture()
    {goal, slot} = create_bucket(scope)
    read_installation_id = Ecto.UUID.generate()

    assert {:ok, read_actor} = ProgressSync.ensure_actor(scope, read_installation_id)

    assert {:ok, %{status: :accepted, revision: 1}} =
             WebSync.increment(
               scope,
               Ecto.UUID.generate(),
               increment_attrs(Ecto.UUID.generate(), goal.id, slot.id)
             )

    assert {:ok,
            %Actor{
              id: actor_id,
              applied_revision: 1,
              safe_compaction_revision: 1
            }} =
             ProgressSync.acknowledge_actor_at_head(scope, read_actor.id)

    assert actor_id == read_actor.id
  end

  defp increment_attrs(command_id, goal_id, slot_id) do
    %{
      command_id: command_id,
      goal_id: goal_id,
      slot_id: slot_id,
      local_date: ~D[2026-07-16],
      timezone: "Asia/Kolkata"
    }
  end

  defp create_bucket(scope) do
    dhikr =
      %Dhikr{}
      |> Dhikr.changeset(%{arabic: "سبحان الله"})
      |> Repo.insert!()

    {:ok, goal} =
      Tracking.create_goal(scope, %{
        id: Ecto.UUID.generate(),
        dhikr_id: dhikr.id,
        start_date: ~D[2026-07-16]
      })

    {:ok, slot} =
      Tracking.create_slot(scope, goal.id, %{
        id: Ecto.UUID.generate(),
        target_count: 100
      })

    Repo.insert!(%EntityRecord{
      user_id: scope.user.id,
      entity_type: "goal",
      entity_id: goal.id,
      incarnation: 1,
      version: 1,
      sync_revision: 1,
      document: %{},
      state: "active"
    })

    {goal, slot}
  end
end
