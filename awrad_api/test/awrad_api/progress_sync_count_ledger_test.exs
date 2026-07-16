defmodule AwradApi.ProgressSyncCountLedgerTest do
  use AwradApi.DataCase, async: true

  alias AwradApi.Dhikr.Dhikr
  alias AwradApi.ProgressSync

  alias AwradApi.ProgressSync.{
    Actor,
    CommandReceipt,
    CountCheckpoint,
    CountConsumption,
    CountCredit,
    CountProjection,
    EntityRecord,
    Head
  }

  alias AwradApi.Tracking

  import AwradApi.AccountsFixtures

  setup do
    scope = user_scope_fixture()
    actor = register_actor(scope)
    {goal, slot} = create_bucket(scope)

    %{scope: scope, actor: actor, goal: goal, slot: slot}
  end

  test "an increment creates one immutable credit and canonical projection", context do
    command = increment(context.actor, 1, context.goal, context.slot, "12")

    assert {:ok,
            %{
              status: :accepted,
              revision: 1,
              effect: %{"applied_amount" => "12", "count" => "12"}
            }} = ProgressSync.execute_count_command(context.scope, command)

    assert %CountCredit{amount: 12, accepted_revision: 1, kind: "increment"} =
             Repo.get!(CountCredit, command.command_id)

    assert projection(context).count == 12

    assert {:ok, %{status: :duplicate, revision: 1, effect: %{"count" => "12"}}} =
             ProgressSync.execute_count_command(context.scope, command)

    assert Repo.aggregate(CountCredit, :count) == 1
  end

  test "positive credits from two devices converge without overwriting", context do
    second_actor = register_actor(context.scope)

    assert {:ok, %{revision: 1, effect: %{"count" => "5"}}} =
             ProgressSync.execute_count_command(
               context.scope,
               increment(context.actor, 1, context.goal, context.slot, "5")
             )

    assert {:ok, %{revision: 2, effect: %{"count" => "12"}}} =
             ProgressSync.execute_count_command(
               context.scope,
               increment(second_actor, 1, context.goal, context.slot, "7")
             )

    assert projection(context).count == 12
    assert Repo.aggregate(CountCredit, :count) == 2
  end

  test "a decrement consumes only credit visible to its observed basis", context do
    second_actor = register_actor(context.scope)

    assert {:ok, %{revision: 1}} =
             ProgressSync.execute_count_command(
               context.scope,
               increment(context.actor, 1, context.goal, context.slot, "5")
             )

    assert {:ok, %{revision: 2}} =
             ProgressSync.execute_count_command(
               context.scope,
               increment(second_actor, 1, context.goal, context.slot, "7")
             )

    correction =
      correction(
        context.actor,
        2,
        context.goal,
        context.slot,
        "decrement_bucket",
        "1",
        "1",
        "10"
      )

    assert {:ok,
            %{
              revision: 3,
              effect: %{
                "requested_amount" => "10",
                "applied_amount" => "5",
                "unapplied_amount" => "5",
                "count" => "7"
              }
            }} = ProgressSync.execute_count_command(context.scope, correction)

    assert projection(context).count == 7
    assert CountConsumption |> Repo.aggregate(:sum, :amount) |> Decimal.to_integer() == 5
  end

  test "a reset includes same-actor credit through its local frontier", context do
    assert {:ok, %{revision: 1, effect: %{"count" => "9"}}} =
             ProgressSync.execute_count_command(
               context.scope,
               increment(context.actor, 1, context.goal, context.slot, "9")
             )

    reset =
      correction(
        context.actor,
        2,
        context.goal,
        context.slot,
        "reset_bucket_observed",
        "0",
        "1"
      )

    assert {:ok, %{revision: 2, effect: %{"applied_amount" => "9", "count" => "0"}}} =
             ProgressSync.execute_count_command(context.scope, reset)

    assert projection(context).count == 0
  end

  test "an explicitly observed local credit is eligible across actor streams", context do
    widget_actor = register_actor(context.scope)
    increment = increment(widget_actor, 1, context.goal, context.slot, "4")

    assert {:ok, %{revision: 1}} =
             ProgressSync.execute_count_command(context.scope, increment)

    correction =
      context.actor
      |> correction(
        1,
        context.goal,
        context.slot,
        "decrement_bucket",
        "0",
        "0",
        "4"
      )
      |> put_in([:payload, "observed_local_credit_ids"], [increment.command_id])

    assert {:ok, %{revision: 2, effect: %{"applied_amount" => "4", "count" => "0"}}} =
             ProgressSync.execute_count_command(context.scope, correction)
  end

  test "a recovery actor frontier implicitly observes its adopted increment", context do
    original = increment(context.actor, 1, context.goal, context.slot, "4")

    assert {:ok, %{status: :accepted, revision: 1}} =
             ProgressSync.execute_count_command(context.scope, original)

    assert {:ok, recovery_actor} =
             ProgressSync.register_actor(context.scope, %{
               id: Ecto.UUID.generate(),
               installation_id: context.actor.installation_id,
               starting_sequence: 1
             })

    adopted = %{original | actor_id: recovery_actor.id}

    assert {:ok, %{status: :duplicate, revision: 1}} =
             ProgressSync.execute_count_command(context.scope, adopted)

    reset =
      correction(
        recovery_actor,
        2,
        context.goal,
        context.slot,
        "reset_bucket_observed",
        "0",
        "1"
      )

    assert {:ok, %{revision: 2, effect: %{"applied_amount" => "4", "count" => "0"}}} =
             ProgressSync.execute_count_command(context.scope, reset)
  end

  test "explicit observations over 500 items retain only the bounded active tail", context do
    foreign_actor = register_actor(context.scope)
    foreign_increment = increment(foreign_actor, 1, context.goal, context.slot, "4")

    assert {:ok, %{status: :accepted, revision: 1}} =
             ProgressSync.execute_count_command(context.scope, foreign_increment)

    irrelevant_ids = Enum.map(1..600, fn _ -> Ecto.UUID.generate() end)

    correction =
      context.actor
      |> correction(
        1,
        context.goal,
        context.slot,
        "decrement_bucket",
        "0",
        "0",
        "4"
      )
      |> put_in(
        [:payload, "observed_local_credit_ids"],
        [foreign_increment.command_id | irrelevant_ids]
      )

    assert {:ok, %{revision: 2, effect: %{"applied_amount" => "4", "count" => "0"}}} =
             ProgressSync.execute_count_command(context.scope, correction)
  end

  test "concurrent destructive intents are server ordered and never create negative debt",
       context do
    second_actor = register_actor(context.scope)

    assert {:ok, %{revision: 1}} =
             ProgressSync.execute_count_command(
               context.scope,
               increment(context.actor, 1, context.goal, context.slot, "5")
             )

    first =
      correction(
        context.actor,
        2,
        context.goal,
        context.slot,
        "decrement_bucket",
        "1",
        "1",
        "4"
      )

    second =
      correction(
        second_actor,
        1,
        context.goal,
        context.slot,
        "decrement_bucket",
        "1",
        "0",
        "4"
      )

    assert {:ok, %{revision: 2, effect: %{"applied_amount" => "4", "count" => "1"}}} =
             ProgressSync.execute_count_command(context.scope, first)

    assert {:ok,
            %{
              revision: 3,
              effect: %{
                "applied_amount" => "1",
                "unapplied_amount" => "3",
                "count" => "0"
              }
            }} = ProgressSync.execute_count_command(context.scope, second)

    assert projection(context).count == 0
    assert CountConsumption |> Repo.aggregate(:sum, :amount) |> Decimal.to_integer() == 5
  end

  test "invalid ownership receives a durable terminal receipt and does not block the actor",
       context do
    other_scope = user_scope_fixture()
    {other_goal, other_slot} = create_bucket(other_scope)
    invalid = increment(context.actor, 1, other_goal, other_slot, "3")

    assert {:ok,
            %{
              status: :invalid,
              revision: 0,
              effect: %{"reason" => "invalid_count_bucket"}
            }} = ProgressSync.execute_count_command(context.scope, invalid)

    assert Repo.get!(Actor, context.actor.id).next_expected_sequence == 2

    assert %CommandReceipt{status: "invalid", result_revision: 0} =
             Repo.get!(CommandReceipt, invalid.command_id)

    assert {:ok, %{status: :invalid, revision: 0}} =
             ProgressSync.execute_count_command(context.scope, invalid)

    assert {:ok, %{status: :accepted, revision: 1}} =
             ProgressSync.execute_count_command(
               context.scope,
               increment(context.actor, 2, context.goal, context.slot, "1")
             )
  end

  test "projection repair derives count from the ledger and advances revision only when changed",
       context do
    assert {:ok, %{revision: 1}} =
             ProgressSync.execute_count_command(
               context.scope,
               increment(context.actor, 1, context.goal, context.slot, "6")
             )

    Repo.update_all(CountProjection, set: [count: 999])

    assert {:ok, %{status: :repaired, revision: 2, count: 6}} =
             ProgressSync.repair_count_projection(
               context.scope,
               bucket(context.goal, context.slot)
             )

    assert projection(context).count == 6
    assert Repo.get!(Head, context.scope.user.id).revision == 2

    assert {:ok, %{status: :unchanged, revision: 2, count: 6}} =
             ProgressSync.repair_count_projection(
               context.scope,
               bucket(context.goal, context.slot)
             )
  end

  test "accepted credit rows are database-immutable", context do
    command = increment(context.actor, 1, context.goal, context.slot, "2")

    assert {:ok, %{status: :accepted}} =
             ProgressSync.execute_count_command(context.scope, command)

    assert_raise Postgrex.Error, ~r/count ledger rows are immutable/, fn ->
      Repo.transaction(
        fn ->
          from(credit in CountCredit, where: credit.id == ^command.command_id)
          |> Repo.update_all(set: [amount: 99])
        end,
        mode: :savepoint
      )
    end

    assert Repo.get!(CountCredit, command.command_id).amount == 2

    assert_raise Postgrex.Error, ~r/consumption exceeds remaining credit/, fn ->
      Repo.transaction(
        fn ->
          %CountConsumption{}
          |> CountConsumption.changeset(
            %{
              correction_command_id: Ecto.UUID.generate(),
              credit_id: command.command_id,
              accepted_revision: 2,
              amount: 3
            },
            context.scope.user.id
          )
          |> Repo.insert!()
        end,
        mode: :savepoint
      )
    end

    assert Repo.aggregate(CountConsumption, :count) == 0
  end

  test "a fully acknowledged ledger compacts and preserves later observed-basis behavior",
       context do
    assert {:ok, %{revision: 1}} =
             ProgressSync.execute_count_command(
               context.scope,
               increment(context.actor, 1, context.goal, context.slot, "5")
             )

    assert {:ok, %{revision: 2, effect: %{"count" => "3"}}} =
             ProgressSync.execute_count_command(
               context.scope,
               correction(
                 context.actor,
                 2,
                 context.goal,
                 context.slot,
                 "decrement_bucket",
                 "1",
                 "1",
                 "2"
               )
             )

    assert {:ok, %Actor{applied_revision: 2, safe_compaction_revision: 2}} =
             ProgressSync.acknowledge_actor(context.scope, context.actor.id, %{
               applied_revision: "2",
               safe_compaction_revision: "2"
             })

    assert {:ok,
            %{
              status: :compacted,
              through_revision: 2,
              count: 3,
              compacted_credit_count: 1
            }} =
             ProgressSync.compact_count_bucket(
               context.scope,
               bucket(context.goal, context.slot)
             )

    assert %CountCheckpoint{through_revision: 2} = Repo.one!(CountCheckpoint)

    assert %CountCredit{kind: "checkpoint", amount: 3, accepted_revision: 2} =
             Repo.one!(CountCredit)

    assert Repo.aggregate(CountConsumption, :count) == 0

    assert {:ok, %{revision: 3, effect: %{"count" => "7"}}} =
             ProgressSync.execute_count_command(
               context.scope,
               increment(context.actor, 3, context.goal, context.slot, "4")
             )

    assert {:ok, %{revision: 4, effect: %{"applied_amount" => "3", "count" => "4"}}} =
             ProgressSync.execute_count_command(
               context.scope,
               correction(
                 context.actor,
                 4,
                 context.goal,
                 context.slot,
                 "decrement_bucket",
                 "2",
                 "2",
                 "10"
               )
             )
  end

  test "one active actor with an unsafe frontier blocks compaction", context do
    second_actor = register_actor(context.scope)

    assert {:ok, %{revision: 1}} =
             ProgressSync.execute_count_command(
               context.scope,
               increment(context.actor, 1, context.goal, context.slot, "5")
             )

    assert {:ok, %Actor{safe_compaction_revision: 1}} =
             ProgressSync.acknowledge_actor(context.scope, context.actor.id, %{
               applied_revision: "1",
               safe_compaction_revision: "1"
             })

    assert {:error, {:actors_not_caught_up, 0, 1}} =
             ProgressSync.compact_count_bucket(
               context.scope,
               bucket(context.goal, context.slot)
             )

    assert {:ok, %Actor{safe_compaction_revision: 1}} =
             ProgressSync.acknowledge_actor(context.scope, second_actor.id, %{
               applied_revision: "1",
               safe_compaction_revision: "1"
             })

    assert {:ok, %{status: :compacted, through_revision: 1}} =
             ProgressSync.compact_count_bucket(
               context.scope,
               bucket(context.goal, context.slot)
             )
  end

  test "a destructive command older than the checkpoint receives stale_basis", context do
    assert {:ok, %{revision: 1}} =
             ProgressSync.execute_count_command(
               context.scope,
               increment(context.actor, 1, context.goal, context.slot, "5")
             )

    assert {:ok, %Actor{safe_compaction_revision: 1}} =
             ProgressSync.acknowledge_actor(context.scope, context.actor.id, %{
               applied_revision: "1",
               safe_compaction_revision: "1"
             })

    assert {:ok, %{status: :compacted}} =
             ProgressSync.compact_count_bucket(
               context.scope,
               bucket(context.goal, context.slot)
             )

    stale =
      correction(
        context.actor,
        2,
        context.goal,
        context.slot,
        "decrement_bucket",
        "0",
        "1",
        "5"
      )

    assert {:ok, %{status: :stale_basis, revision: 1, effect: %{"reason" => "stale_basis"}}} =
             ProgressSync.execute_count_command(context.scope, stale)

    assert {:ok, %{status: :stale_basis, revision: 1}} =
             ProgressSync.execute_count_command(context.scope, stale)

    assert projection(context).count == 5
    assert Repo.aggregate(CountConsumption, :count) == 0
    assert Repo.get!(Actor, context.actor.id).next_expected_sequence == 3
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

  defp register_actor(scope) do
    {:ok, actor} =
      ProgressSync.register_actor(scope, %{
        id: Ecto.UUID.generate(),
        installation_id: Ecto.UUID.generate(),
        incarnation: 1
      })

    actor
  end

  defp increment(actor, sequence, goal, slot, amount) do
    %{
      command_id: Ecto.UUID.generate(),
      actor_id: actor.id,
      actor_sequence: Integer.to_string(sequence),
      payload:
        Map.merge(bucket(goal, slot), %{
          "type" => "increment",
          "amount" => amount
        })
    }
  end

  defp correction(actor, sequence, goal, slot, type, basis, frontier, amount \\ nil) do
    payload =
      bucket(goal, slot)
      |> Map.merge(%{
        "type" => type,
        "basis_revision" => basis,
        "local_frontier_sequence" => frontier,
        "observed_local_credit_ids" => []
      })
      |> then(fn payload -> if amount, do: Map.put(payload, "amount", amount), else: payload end)

    %{
      command_id: Ecto.UUID.generate(),
      actor_id: actor.id,
      actor_sequence: Integer.to_string(sequence),
      payload: payload
    }
  end

  defp bucket(goal, slot) do
    %{
      "goal_id" => goal.id,
      "slot_id" => slot.id,
      "local_date" => "2026-07-16",
      "entity_incarnation" => "1"
    }
  end

  defp projection(context) do
    local_date = ~D[2026-07-16]

    Repo.one!(
      from projection in CountProjection,
        where:
          projection.user_id == ^context.scope.user.id and
            projection.goal_id == ^context.goal.id and projection.slot_id == ^context.slot.id and
            projection.local_date == ^local_date
    )
  end
end
