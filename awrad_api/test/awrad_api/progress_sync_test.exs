defmodule AwradApi.ProgressSyncTest do
  use AwradApi.DataCase, async: true

  alias AwradApi.ProgressSync
  alias AwradApi.ProgressSync.{Actor, CommandReceipt, Head, Maintenance, ReceiptAdoption}

  import AwradApi.AccountsFixtures

  setup do
    scope = user_scope_fixture()
    actor_id = Ecto.UUID.generate()
    installation_id = Ecto.UUID.generate()

    assert {:ok, actor} =
             ProgressSync.register_actor(scope, %{
               id: actor_id,
               installation_id: installation_id,
               incarnation: 1,
               user_id: Ecto.UUID.generate(),
               next_expected_sequence: 99
             })

    %{scope: scope, actor: actor}
  end

  test "actor registration derives ownership and creates a revision head", %{
    scope: scope,
    actor: actor
  } do
    assert actor.user_id == scope.user.id
    assert actor.next_expected_sequence == 1
    assert %Head{revision: 0, generation: 1} = Repo.get!(Head, scope.user.id)

    assert {:ok, same_actor} =
             ProgressSync.register_actor(scope, %{
               id: actor.id,
               installation_id: actor.installation_id,
               incarnation: actor.incarnation
             })

    assert same_actor.id == actor.id
    assert Repo.aggregate(Actor, :count) == 1
  end

  test "a replacement actor on the same installation gets a server incarnation", %{
    scope: scope,
    actor: first_actor
  } do
    replacement_id = Ecto.UUID.generate()

    assert {:ok, replacement} =
             ProgressSync.register_actor(scope, %{
               id: replacement_id,
               installation_id: first_actor.installation_id,
               # Client input is deliberately ignored for a new actor.
               incarnation: 999
             })

    assert replacement.id == replacement_id
    assert replacement.incarnation == first_actor.incarnation + 1
    assert is_nil(replacement.retired_at)
    assert %Actor{retired_at: nil} = Repo.get!(Actor, first_actor.id)
  end

  test "active actor registration is bounded per account", %{scope: scope} do
    for _ <- 1..31 do
      assert {:ok, %Actor{}} =
               ProgressSync.register_actor(scope, %{
                 id: Ecto.UUID.generate(),
                 installation_id: Ecto.UUID.generate(),
                 incarnation: 1
               })
    end

    assert {:error, :actor_quota_exceeded} =
             ProgressSync.register_actor(scope, %{
               id: Ecto.UUID.generate(),
               installation_id: Ecto.UUID.generate(),
               incarnation: 1
             })
  end

  test "an expired actor cannot be resurrected", %{scope: scope, actor: actor} do
    actor
    |> Ecto.Changeset.change(
      lease_expires_at: DateTime.add(DateTime.utc_now(:second), -1, :second)
    )
    |> Repo.update!()

    assert %{retired_actors: 1} = Maintenance.run_once()
    refute is_nil(Repo.get!(Actor, actor.id).retired_at)

    assert {:error, :actor_fork} =
             ProgressSync.register_actor(scope, %{
               id: actor.id,
               installation_id: actor.installation_id,
               incarnation: actor.incarnation
             })
  end

  test "wire UUIDs must use canonical lowercase form", %{scope: scope} do
    assert {:error, :invalid_uuid_v4} =
             ProgressSync.register_actor(scope, %{
               id: Ecto.UUID.generate() |> String.upcase(),
               installation_id: Ecto.UUID.generate(),
               incarnation: 1
             })
  end

  test "an accepted command advances one user revision and stores its canonical effect", %{
    scope: scope,
    actor: actor
  } do
    command_id = Ecto.UUID.generate()

    assert {:ok,
            %{
              status: :accepted,
              command_id: ^command_id,
              revision: 1,
              effect: %{"accepted_count" => "3"}
            }} =
             ProgressSync.execute_command(
               scope,
               command(actor, command_id, 1, %{"delta" => "3"}),
               fn revision ->
                 assert revision == 1
                 {:ok, %{"accepted_count" => "3"}}
               end
             )

    assert %Head{revision: 1} = Repo.get!(Head, scope.user.id)
    assert %Actor{next_expected_sequence: 2} = Repo.get!(Actor, actor.id)

    assert %CommandReceipt{
             command_id: ^command_id,
             status: "accepted",
             result_revision: 1,
             canonical_effect: %{"accepted_count" => "3"}
           } = Repo.get!(CommandReceipt, command_id)
  end

  test "an exact retry returns the stored receipt without running the handler", %{
    scope: scope,
    actor: actor
  } do
    command_id = Ecto.UUID.generate()
    request = command(actor, command_id, 1, %{"delta" => "7", "bucket" => "today"})

    assert {:ok, %{status: :accepted, revision: 1}} =
             ProgressSync.execute_command(scope, request, fn _revision ->
               {:ok, %{"accepted_count" => "7"}}
             end)

    assert {:ok, %{status: :duplicate, revision: 1, effect: %{"accepted_count" => "7"}}} =
             ProgressSync.execute_command(scope, request, fn _revision ->
               flunk("duplicate command ran its mutation twice")
             end)

    assert Repo.get!(Head, scope.user.id).revision == 1
    assert Repo.aggregate(CommandReceipt, :count) == 1
  end

  test "a recovering actor durably adopts an identical lost-response receipt and continues", %{
    scope: scope,
    actor: original_actor
  } do
    command_id = Ecto.UUID.generate()
    original = command(original_actor, command_id, 1, %{"delta" => "7"})

    assert {:ok, %{status: :accepted, revision: 1}} =
             ProgressSync.execute_command(scope, original, fn _revision ->
               {:ok, %{"accepted_count" => "7"}}
             end)

    original_actor
    |> Ecto.Changeset.change(
      lease_expires_at: DateTime.add(DateTime.utc_now(:second), -1, :second)
    )
    |> Repo.update!()

    assert {:ok, recovering_actor} =
             ProgressSync.register_actor(scope, %{
               id: Ecto.UUID.generate(),
               installation_id: original_actor.installation_id,
               incarnation: 999,
               starting_sequence: 1
             })

    mismatched =
      command(recovering_actor, command_id, 1, %{"delta" => "8"})

    assert {:error, :idempotency_collision} =
             ProgressSync.execute_command(scope, mismatched, &accepted/1)

    adopted = command(recovering_actor, command_id, 1, %{"delta" => "7"})

    assert {:ok, %{status: :duplicate, revision: 1, effect: %{"accepted_count" => "7"}}} =
             ProgressSync.execute_command(scope, adopted, fn _revision ->
               flunk("adopted receipt ran its mutation twice")
             end)

    assert %Actor{next_expected_sequence: 2} = Repo.get!(Actor, recovering_actor.id)
    assert Repo.aggregate(ReceiptAdoption, :count) == 1

    # A second lost response is also durable and does not advance twice.
    assert {:ok, %{status: :duplicate, revision: 1}} =
             ProgressSync.execute_command(scope, adopted, fn _revision ->
               flunk("durable adoption ran its mutation twice")
             end)

    assert %Actor{next_expected_sequence: 2} = Repo.get!(Actor, recovering_actor.id)
    assert Repo.aggregate(ReceiptAdoption, :count) == 1

    assert {:ok, %{status: :accepted, revision: 2}} =
             ProgressSync.execute_command(
               scope,
               command(recovering_actor, Ecto.UUID.generate(), 2, %{"delta" => "1"}),
               &accepted/1
             )
  end

  test "receipt adoption rejects another installation and account", %{
    scope: scope,
    actor: original_actor
  } do
    command_id = Ecto.UUID.generate()
    original = command(original_actor, command_id, 1, %{"delta" => "7"})

    assert {:ok, %{status: :accepted}} =
             ProgressSync.execute_command(scope, original, &accepted/1)

    assert {:ok, other_installation_actor} =
             ProgressSync.register_actor(scope, %{
               id: Ecto.UUID.generate(),
               installation_id: Ecto.UUID.generate(),
               incarnation: 1,
               starting_sequence: 1
             })

    assert {:error, :idempotency_collision} =
             ProgressSync.execute_command(
               scope,
               command(other_installation_actor, command_id, 1, %{"delta" => "7"}),
               &accepted/1
             )

    other_scope = user_scope_fixture()

    assert {:ok, other_user_actor} =
             ProgressSync.register_actor(other_scope, %{
               id: Ecto.UUID.generate(),
               installation_id: Ecto.UUID.generate(),
               incarnation: 1,
               starting_sequence: 1
             })

    assert {:error, :command_identity_collision} =
             ProgressSync.execute_command(
               other_scope,
               command(other_user_actor, command_id, 1, %{"delta" => "7"}),
               &accepted/1
             )
  end

  test "the same command id with another payload is an idempotency collision", %{
    scope: scope,
    actor: actor
  } do
    command_id = Ecto.UUID.generate()

    assert {:ok, %{status: :accepted}} =
             ProgressSync.execute_command(
               scope,
               command(actor, command_id, 1, %{"delta" => "1"}),
               &accepted/1
             )

    assert {:error, :idempotency_collision} =
             ProgressSync.execute_command(
               scope,
               command(actor, command_id, 1, %{"delta" => "2"}),
               &accepted/1
             )
  end

  test "a reused actor sequence is a fork and a future sequence is a gap", %{
    scope: scope,
    actor: actor
  } do
    assert {:ok, %{status: :accepted}} =
             ProgressSync.execute_command(
               scope,
               command(actor, Ecto.UUID.generate(), 1, %{"delta" => "1"}),
               &accepted/1
             )

    assert {:error, :actor_fork} =
             ProgressSync.execute_command(
               scope,
               command(actor, Ecto.UUID.generate(), 1, %{"delta" => "1"}),
               &accepted/1
             )

    assert {:error, {:sequence_gap, 2}} =
             ProgressSync.execute_command(
               scope,
               command(actor, Ecto.UUID.generate(), 3, %{"delta" => "1"}),
               &accepted/1
             )
  end

  test "actors and command ownership cannot cross authenticated user scopes", %{actor: actor} do
    other_scope = user_scope_fixture()

    assert {:error, :unknown_actor} =
             ProgressSync.execute_command(
               other_scope,
               command(actor, Ecto.UUID.generate(), 1, %{"delta" => "1"}),
               &accepted/1
             )
  end

  test "canonical hashing ignores map insertion order", %{scope: scope, actor: actor} do
    command_id = Ecto.UUID.generate()
    first_payload = Map.new([{"z", "last"}, {"a", %{"b" => "2", "a" => "1"}}])
    retry_payload = Map.new([{"a", %{"a" => "1", "b" => "2"}}, {"z", "last"}])

    assert {:ok, %{status: :accepted}} =
             ProgressSync.execute_command(
               scope,
               command(actor, command_id, 1, first_payload),
               &accepted/1
             )

    assert {:ok, %{status: :duplicate}} =
             ProgressSync.execute_command(
               scope,
               command(actor, command_id, 1, retry_payload),
               &accepted/1
             )
  end

  test "a failed mutation does not consume the actor sequence or user revision", %{
    scope: scope,
    actor: actor
  } do
    request = command(actor, Ecto.UUID.generate(), 1, %{"delta" => "99"})

    assert {:error, :cap_exceeded} =
             ProgressSync.execute_command(scope, request, fn _revision ->
               {:error, :cap_exceeded}
             end)

    assert Repo.get!(Head, scope.user.id).revision == 0
    assert Repo.get!(Actor, actor.id).next_expected_sequence == 1
    assert Repo.aggregate(CommandReceipt, :count) == 0

    assert {:ok, %{status: :accepted, revision: 1}} =
             ProgressSync.execute_command(scope, request, &accepted/1)
  end

  test "non-JSON payloads are rejected before the mutation runs", %{scope: scope, actor: actor} do
    request = command(actor, Ecto.UUID.generate(), 1, %{delta: 1.5})

    assert {:error, :non_canonical_json} =
             ProgressSync.execute_command(scope, request, fn _revision ->
               flunk("invalid payload reached the mutation")
             end)
  end

  test "different actors for one user receive distinct commit-ordered revisions", %{
    scope: scope,
    actor: first_actor
  } do
    assert {:ok, second_actor} =
             ProgressSync.register_actor(scope, %{
               id: Ecto.UUID.generate(),
               installation_id: Ecto.UUID.generate(),
               incarnation: 1
             })

    tasks =
      for actor <- [first_actor, second_actor] do
        Task.async(fn ->
          receive do
            :execute ->
              ProgressSync.execute_command(
                scope,
                command(actor, Ecto.UUID.generate(), 1, %{"delta" => "1"}),
                &accepted/1
              )
          end
        end)
      end

    Enum.each(tasks, fn task ->
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), task.pid)
      send(task.pid, :execute)
    end)

    revisions =
      tasks
      |> Enum.map(&Task.await/1)
      |> Enum.map(fn {:ok, %{status: :accepted, revision: revision}} -> revision end)

    assert Enum.sort(revisions) == [1, 2]
    assert Repo.get!(Head, scope.user.id).revision == 2
  end

  defp command(actor, command_id, sequence, payload) do
    %{
      command_id: command_id,
      actor_id: actor.id,
      actor_sequence: sequence,
      payload: payload
    }
  end

  defp accepted(revision), do: {:ok, %{"revision" => revision}}
end
