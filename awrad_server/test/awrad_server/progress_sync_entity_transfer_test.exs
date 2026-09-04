defmodule AwradServer.ProgressSyncEntityTransferTest do
  use AwradServer.DataCase, async: true

  import AwradServer.AccountsFixtures

  alias AwradServer.ProgressSync

  alias AwradServer.ProgressSync.{
    CommandReceipt,
    EntityConflict,
    EntityRecord,
    Maintenance,
    ReceiptAdoption,
    Transfer,
    TransferSession
  }

  alias AwradServer.Repo
  alias AwradServer.Tracking.{Goal, GoalSlot}

  setup do
    scope = user_scope_fixture()

    {:ok, actor} =
      ProgressSync.register_actor(scope, %{
        id: Ecto.UUID.generate(),
        installation_id: Ecto.UUID.generate(),
        incarnation: 1
      })

    fixture =
      "../contracts/progress-model/v1/fixtures/progress-state.json"
      |> File.read!()
      |> Jason.decode!()

    dhikr =
      fixture["dhikrs"] |> Enum.find(& &1["is_custom"]) |> Map.put("id", Ecto.UUID.generate())

    goal_id = Ecto.UUID.generate()

    slots =
      fixture["goals"]
      |> hd()
      |> Map.fetch!("slots")
      |> Enum.take(1)
      |> Enum.map(&(&1 |> Map.put("id", Ecto.UUID.generate()) |> Map.put("goal_id", goal_id)))

    reminders =
      fixture["goals"]
      |> hd()
      |> Map.fetch!("reminders")
      |> Enum.map(&(&1 |> Map.put("id", Ecto.UUID.generate()) |> Map.put("goal_id", goal_id)))

    goal =
      fixture["goals"]
      |> hd()
      |> Map.put("id", goal_id)
      |> Map.put("dhikr_id", dhikr["id"])
      |> Map.put("slots", slots)
      |> Map.put("reminders", reminders)

    %{scope: scope, actor: actor, dhikr: dhikr, goal: goal, slot: hd(slots)}
  end

  test "whole-document entities materialize and immutable snapshot pages include canonical state",
       context do
    assert {:ok, %{status: :accepted, revision: 1}} =
             put_entity(context, 1, "custom_dhikr", context.dhikr, 0)

    assert {:ok, %{status: :accepted, revision: 2}} =
             put_entity(context, 2, "goal", context.goal, 0)

    assert %Goal{user_id: user_id, dhikr_id: dhikr_id} = Repo.get!(Goal, context.goal["id"])
    assert user_id == context.scope.user.id
    assert dhikr_id == context.dhikr["id"]
    assert %GoalSlot{goal_id: goal_id} = Repo.get!(GoalSlot, context.slot["id"])
    assert goal_id == context.goal["id"]

    assert {:ok, session} = Transfer.start(context.scope, "snapshot")
    assert session["through_revision"] == "2"
    assert session["record_count"] == 2
    assert session["page_count"] == 1

    assert {:ok, page} = Transfer.page(context.scope, session["transfer_id"], 1)
    assert Enum.map(page["records"], & &1["kind"]) == ["custom_dhikr", "goal"]

    assert {:ok, delta} = Transfer.start(context.scope, "delta", session["cursor"])
    assert delta["record_count"] == 0

    session_count = Repo.aggregate(TransferSession, :count)

    assert {:ok, unchanged} =
             Transfer.start(context.scope, "delta", session["cursor"], allow_unchanged: true)

    assert unchanged["status"] == "unchanged"
    assert unchanged["through_revision"] == "2"
    assert Repo.aggregate(TransferSession, :count) == session_count

    assert {:ok, _head} = ProgressSync.bump_generation(context.scope)
    assert {:error, :generation_reset} = Transfer.start(context.scope, "delta", session["cursor"])
  end

  test "a signed delta cursor is bound to its authenticated account", context do
    assert {:ok, session} = Transfer.start(context.scope, "snapshot", nil)
    other_scope = user_scope_fixture()

    assert {:error, :invalid_cursor} =
             Transfer.start(other_scope, "delta", session["cursor"])
  end

  test "fetching a final page frees quota without breaking page retries", context do
    sessions =
      for _ <- 1..12 do
        assert {:ok, session} = Transfer.start(context.scope, "snapshot", nil)
        assert {:ok, _page} = Transfer.page(context.scope, session["transfer_id"], 1)
        session
      end

    assert Repo.aggregate(
             from(session in TransferSession, where: session.status == "completed"),
             :count
           ) == 12

    first = hd(sessions)
    assert {:ok, _retry} = Transfer.page(context.scope, first["transfer_id"], 1)
  end

  test "eight unfinished transfers retain the active-session quota", context do
    for _ <- 1..8 do
      assert {:ok, _session} = Transfer.start(context.scope, "snapshot", nil)
    end

    assert {:error, :transfer_quota_exceeded} =
             Transfer.start(context.scope, "snapshot", nil)
  end

  test "stale different update preserves a durable conflict and leaves cloud document unchanged",
       context do
    assert {:ok, %{status: :accepted}} = put_entity(context, 1, "custom_dhikr", context.dhikr, 0)

    first = Map.put(context.dhikr, "title", "Cloud title")

    assert {:ok, %{status: :accepted, effect: %{"entity_version" => "2"}}} =
             put_entity(context, 2, "custom_dhikr", first, 1)

    assert {:ok, before_conflict} = Transfer.start(context.scope, "snapshot", nil)

    stale = Map.put(context.dhikr, "title", "Offline title")

    stale_command =
      command(context.actor, 3, %{
        "type" => "entity_upsert",
        "entity_type" => "custom_dhikr",
        "entity_id" => stale["id"],
        "base_version" => "1",
        "entity_incarnation" => "1",
        "proposed_document" => stale
      })

    assert {:ok, %{status: :conflict, revision: 3, effect: %{"entity_version" => "2"}}} =
             ProgressSync.execute_progress_command(context.scope, stale_command)

    assert {:ok, %{status: :conflict, effect: %{"entity_version" => "2"}}} =
             ProgressSync.execute_progress_command(context.scope, stale_command)

    assert %EntityRecord{document: %{"title" => "Cloud title"}} =
             Repo.get_by!(EntityRecord,
               user_id: context.scope.user.id,
               entity_type: "custom_dhikr",
               entity_id: context.dhikr["id"]
             )

    assert %EntityConflict{proposed_document: %{"title" => "Offline title"}} =
             Repo.one!(EntityConflict)

    assert {:ok, conflict_delta} =
             Transfer.start(context.scope, "delta", before_conflict["cursor"])

    assert {:ok, conflict_page} =
             Transfer.page(context.scope, conflict_delta["transfer_id"], 1)

    assert Enum.any?(conflict_page["records"], &(&1["kind"] == "conflict"))

    assert {:ok, %{status: :accepted, revision: 4}} =
             lifecycle(
               context,
               4,
               "entity_accept_canonical",
               "custom_dhikr",
               context.dhikr["id"],
               2,
               1
             )

    assert {:ok, resolution_delta} =
             Transfer.start(context.scope, "delta", conflict_delta["cursor"])

    assert {:ok, resolution_page} =
             Transfer.page(context.scope, resolution_delta["transfer_id"], 1)

    assert Enum.any?(resolution_page["records"], fn record ->
             record["kind"] == "conflict" and record["payload"]["resolved"] == true and
               record["sync_revision"] == "4"
           end)

    assert {:ok, clean_snapshot} = Transfer.start(context.scope, "snapshot", nil)
    assert {:ok, clean_page} = Transfer.page(context.scope, clean_snapshot["transfer_id"], 1)
    refute Enum.any?(clean_page["records"], &(&1["kind"] == "conflict"))
  end

  test "deletion fences old-incarnation counts and restore advances the incarnation", context do
    assert {:ok, %{status: :accepted}} = put_entity(context, 1, "custom_dhikr", context.dhikr, 0)
    assert {:ok, %{status: :accepted}} = put_entity(context, 2, "goal", context.goal, 0)

    assert {:ok, %{status: :accepted, effect: %{"state" => "deleted"}}} =
             lifecycle(context, 3, "entity_delete", "goal", context.goal["id"], 1, 1)

    offline_increment =
      command(context.actor, 4, %{
        "type" => "increment",
        "goal_id" => context.goal["id"],
        "slot_id" => context.slot["id"],
        "local_date" => "2026-07-16",
        "amount" => "1",
        "entity_incarnation" => "1"
      })

    assert {:ok, %{status: :gone}} =
             ProgressSync.execute_progress_command(context.scope, offline_increment)

    assert {:ok, %{status: :accepted, effect: %{"entity_incarnation" => "2"}}} =
             lifecycle(context, 5, "entity_restore", "goal", context.goal["id"], 2, 1)

    # Deletion wins in v1. The terminal receipt is durable and the old
    # incarnation is never silently replayed into the restored goal.
    assert {:ok, %{status: :gone}} =
             ProgressSync.execute_progress_command(context.scope, offline_increment)
  end

  test "maintenance purges expired goal payload and transfer pages into a deletion fence",
       context do
    assert {:ok, %{status: :accepted}} = put_entity(context, 1, "custom_dhikr", context.dhikr, 0)
    assert {:ok, %{status: :accepted}} = put_entity(context, 2, "goal", context.goal, 0)

    assert {:ok, %{status: :accepted}} =
             lifecycle(context, 3, "entity_delete", "goal", context.goal["id"], 1, 1)

    entity =
      Repo.get_by!(EntityRecord,
        user_id: context.scope.user.id,
        entity_type: "goal",
        entity_id: context.goal["id"]
      )

    past = DateTime.add(DateTime.utc_now(:second), -1, :second)
    entity |> Ecto.Changeset.change(purge_after: past) |> Repo.update!()

    assert {:ok, session} = Transfer.start(context.scope, "snapshot", nil)
    transfer = Repo.get!(TransferSession, session["transfer_id"])
    transfer |> Ecto.Changeset.change(expires_at: past) |> Repo.update!()

    assert %{purged_entities: 1, expired_transfers: 1} = Maintenance.run_once()

    purged = Repo.get!(EntityRecord, entity.id)
    assert purged.state == "purged"
    assert purged.document == nil
    refute Repo.get(Goal, context.goal["id"])
    assert {:error, :transfer_not_found} = Transfer.page(context.scope, session["transfer_id"], 1)

    assert {:ok, fence} = Transfer.start(context.scope, "snapshot", nil)
    assert {:ok, page} = Transfer.page(context.scope, fence["transfer_id"], 1)

    assert Enum.any?(
             page["records"],
             &(&1["kind"] == "deletion_fence" && &1["id"] == context.goal["id"])
           )
  end

  test "ordinary and adopted lost-response replays become the canonical purge fence", context do
    assert {:ok, %{status: :accepted}} = put_entity(context, 1, "custom_dhikr", context.dhikr, 0)

    goal_create =
      command(context.actor, 2, %{
        "type" => "entity_upsert",
        "entity_type" => "goal",
        "entity_id" => context.goal["id"],
        "base_version" => "0",
        "entity_incarnation" => "1",
        "proposed_document" => context.goal
      })

    # Simulate an accepted response that the originating device never durably
    # recorded before another device deletes and retention purges the goal.
    assert {:ok, %{status: :accepted, revision: 2}} =
             ProgressSync.execute_progress_command(context.scope, goal_create)

    assert {:ok, %{status: :accepted, revision: 3}} =
             lifecycle(context, 3, "entity_delete", "goal", context.goal["id"], 1, 1)

    entity =
      Repo.get_by!(EntityRecord,
        user_id: context.scope.user.id,
        entity_type: "goal",
        entity_id: context.goal["id"]
      )

    entity
    |> Ecto.Changeset.change(purge_after: DateTime.add(DateTime.utc_now(:second), -1, :second))
    |> Repo.update!()

    assert %{purged_entities: 1} = Maintenance.run_once()

    expected_fence = %{
      "kind" => "deletion_fence",
      "purged" => true,
      "entity_id" => context.goal["id"],
      "entity_type" => "goal",
      "entity_incarnation" => "1",
      "entity_version" => "3",
      "state" => "purged",
      "document" => nil
    }

    assert %CommandReceipt{
             status: "gone",
             result_revision: 4,
             canonical_effect: ^expected_fence
           } = Repo.get!(CommandReceipt, goal_create.command_id)

    assert {:ok, %{status: :gone, revision: 4, effect: ^expected_fence}} =
             ProgressSync.execute_progress_command(context.scope, goal_create)

    assert {:ok, recovery_actor} =
             ProgressSync.register_actor(context.scope, %{
               id: Ecto.UUID.generate(),
               installation_id: context.actor.installation_id,
               starting_sequence: 2
             })

    adopted = %{goal_create | actor_id: recovery_actor.id}

    assert {:ok, %{status: :gone, revision: 4, effect: ^expected_fence}} =
             ProgressSync.execute_progress_command(context.scope, adopted)

    assert Repo.get!(AwradServer.ProgressSync.Actor, recovery_actor.id).next_expected_sequence ==
             3

    assert Repo.aggregate(ReceiptAdoption, :count) == 1
  end

  test "mobile documents may omit nullable members and are stored canonically", context do
    dhikr = Map.drop(context.dhikr, ~w(catalog_key audio_url audio_file_name quran_ref))

    goal =
      context.goal
      |> Map.drop(~w(end_date duration_days completed_at))
      |> Map.update!("count_policy", &Map.drop(&1, ~w(minimum_count maximum_count)))
      |> Map.update!("recurrence", &Map.drop(&1, ~w(interval_days anchor_date month season_code)))
      |> Map.update!("slots", fn slots ->
        Enum.map(slots, fn slot ->
          slot
          |> Map.drop(
            ~w(prayer_name prayer_relation start_minute end_minute start_lead_minutes_override label archived_at)
          )
          |> Map.update!("count_policy", &Map.drop(&1, ~w(minimum_count maximum_count)))
        end)
      end)
      |> Map.update!("reminders", fn reminders ->
        Enum.map(reminders, &Map.drop(&1, ~w(slot_id hour minute offset_minutes)))
      end)

    assert {:ok, %{status: :accepted}} = put_entity(context, 1, "custom_dhikr", dhikr, 0)
    assert {:ok, %{status: :accepted}} = put_entity(context, 2, "goal", goal, 0)

    stored =
      Repo.get_by!(EntityRecord,
        user_id: context.scope.user.id,
        entity_type: "goal",
        entity_id: goal["id"]
      ).document

    assert Map.fetch!(stored, "end_date") == nil
    assert Map.fetch!(stored["count_policy"], "minimum_count") == nil
    assert Map.fetch!(hd(stored["slots"]), "prayer_name") == nil
  end

  test "entity documents enforce canonical UUID, UTC, int64, and byte bounds", context do
    uppercase_id = Map.put(context.dhikr, "id", String.upcase(context.dhikr["id"]))
    assert {:ok, %{status: :invalid}} = put_entity(context, 1, "custom_dhikr", uppercase_id, 0)

    assert {:ok, %{status: :accepted}} = put_entity(context, 2, "custom_dhikr", context.dhikr, 0)

    non_utc = Map.put(context.goal, "created_at", "2026-07-16T12:00:00+05:30")
    assert {:ok, %{status: :invalid}} = put_entity(context, 3, "goal", non_utc, 0)

    overflow =
      Map.update!(context.goal, "count_policy", fn policy ->
        Map.put(policy, "target_count", 9_223_372_036_854_775_808)
      end)

    assert {:ok, %{status: :invalid}} = put_entity(context, 4, "goal", overflow, 0)

    oversized = Map.put(context.dhikr, "title", String.duplicate("x", 512_001))
    assert {:ok, %{status: :invalid}} = put_entity(context, 5, "custom_dhikr", oversized, 0)
  end

  test "canonical cumulative counts automatically complete and reopen a goal", context do
    policy =
      context.goal["count_policy"]
      |> Map.put("minimum_count", nil)
      |> Map.put("target_count", 2)
      |> Map.put("completion_threshold", "target")

    slots =
      Enum.map(context.goal["slots"], fn slot ->
        Map.update!(slot, "count_policy", fn policy ->
          policy |> Map.put("minimum_count", nil) |> Map.put("target_count", 2)
        end)
      end)

    goal =
      context.goal
      |> Map.put("target_policy", "cumulative_total")
      |> Map.put("completion_policy", "when_target_reached")
      |> Map.put("count_policy", policy)
      |> Map.put("slots", slots)

    assert {:ok, %{status: :accepted}} = put_entity(context, 1, "custom_dhikr", context.dhikr, 0)
    assert {:ok, %{status: :accepted}} = put_entity(context, 2, "goal", goal, 0)

    assert {:ok, %{status: :accepted}} =
             ProgressSync.execute_progress_command(
               context.scope,
               command(context.actor, 3, %{
                 "type" => "increment",
                 "goal_id" => goal["id"],
                 "slot_id" => context.slot["id"],
                 "local_date" => "2026-07-16",
                 "amount" => "2",
                 "entity_incarnation" => "1"
               })
             )

    completed =
      Repo.get_by!(EntityRecord,
        user_id: context.scope.user.id,
        entity_type: "goal",
        entity_id: goal["id"]
      )

    assert completed.completion_origin == "automatic"
    assert completed.document["is_active"] == false
    assert is_binary(completed.document["completed_at"])

    stale_projection_edit = Map.put(goal, "end_date", "2026-12-31")

    assert {:ok, %{status: :accepted, effect: %{"entity_version" => "2"}}} =
             put_entity(context, 4, "goal", stale_projection_edit, 1)

    after_edit = Repo.get!(EntityRecord, completed.id)
    assert after_edit.document["end_date"] == "2026-12-31"
    assert after_edit.document["is_active"] == false
    assert after_edit.document["completed_at"] == completed.document["completed_at"]

    assert {:ok, %{status: :accepted}} =
             ProgressSync.execute_progress_command(
               context.scope,
               command(context.actor, 5, %{
                 "type" => "decrement_bucket",
                 "goal_id" => goal["id"],
                 "slot_id" => context.slot["id"],
                 "local_date" => "2026-07-16",
                 "amount" => "2",
                 "basis_revision" => "3",
                 "local_frontier_sequence" => "4",
                 "observed_local_credit_ids" => [],
                 "entity_incarnation" => "1"
               })
             )

    reopened = Repo.get!(EntityRecord, completed.id)
    assert reopened.completion_origin == nil
    assert reopened.document["is_active"] == true
    assert reopened.document["completed_at"] == nil
  end

  test "legacy custom dhikr updates preserve additional categories", context do
    initial = Map.put(context.dhikr, "categories", ["general", "morning", "after_salah"])

    assert {:ok, %{status: :accepted}} = put_entity(context, 1, "custom_dhikr", initial, 0)

    legacy_update =
      initial
      |> Map.delete("categories")
      |> Map.put("category", "evening")

    assert {:ok, %{status: :accepted}} =
             put_entity(context, 2, "custom_dhikr", legacy_update, 1)

    record =
      Repo.one!(
        from entity in EntityRecord,
          where:
            entity.user_id == ^context.scope.user.id and
              entity.entity_type == "custom_dhikr" and entity.entity_id == ^initial["id"]
      )

    assert record.document["category"] == "evening"
    assert record.document["categories"] == ["evening", "morning", "after_salah"]
  end

  defp put_entity(context, sequence, type, document, base_version) do
    ProgressSync.execute_progress_command(
      context.scope,
      command(context.actor, sequence, %{
        "type" => "entity_upsert",
        "entity_type" => type,
        "entity_id" => document["id"],
        "base_version" => Integer.to_string(base_version),
        "entity_incarnation" => "1",
        "proposed_document" => document
      })
    )
  end

  defp lifecycle(context, sequence, type, entity_type, entity_id, version, incarnation) do
    ProgressSync.execute_progress_command(
      context.scope,
      command(context.actor, sequence, %{
        "type" => type,
        "entity_type" => entity_type,
        "entity_id" => entity_id,
        "base_version" => Integer.to_string(version),
        "entity_incarnation" => Integer.to_string(incarnation)
      })
    )
  end

  defp command(actor, sequence, payload) do
    %{
      command_id: Ecto.UUID.generate(),
      actor_id: actor.id,
      actor_sequence: Integer.to_string(sequence),
      payload: payload
    }
  end
end
