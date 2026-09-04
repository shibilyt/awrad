defmodule AwradServer.ProgressSyncDhikrTagsTest do
  use AwradServer.DataCase, async: false

  import AwradServer.AccountsFixtures

  alias AwradServer.ProgressSync
  alias AwradServer.ProgressSync.{Document, EntityRecord, Transfer}
  alias AwradServer.Repo

  setup do
    scope = user_scope_fixture()

    {:ok, actor} =
      ProgressSync.register_actor(scope, %{
        id: Ecto.UUID.generate(),
        installation_id: Ecto.UUID.generate(),
        incarnation: 1
      })

    %{scope: scope, actor: actor}
  end

  test "user_tag upserts persist through the entity store", context do
    tag_id = Ecto.UUID.generate()
    {:ok, _display, normalized} = Document.normalize_tag_name("Before Sleep")

    document = %{
      "id" => tag_id,
      "name" => "Before Sleep",
      "normalized_name" => normalized,
      "created_at" => "2026-07-24T10:00:00Z",
      "updated_at" => "2026-07-24T10:00:00Z"
    }

    assert {:ok, %{status: :accepted, effect: %{"entity_id" => ^tag_id, "state" => "active"}}} =
             put_entity(context, 1, "user_tag", document, 0)

    stored =
      Repo.get_by!(EntityRecord,
        user_id: context.scope.user.id,
        entity_type: "user_tag",
        entity_id: tag_id
      )

    assert stored.document["normalized_name"] == "before sleep"
  end

  test "concurrent-style duplicate normalized tag creates coalesce to the canonical id",
       context do
    first_id = Ecto.UUID.generate()
    second_id = Ecto.UUID.generate()
    {:ok, _, normalized} = Document.normalize_tag_name("Before Sleep")

    first = %{
      "id" => first_id,
      "name" => "Before Sleep",
      "normalized_name" => normalized,
      "created_at" => "2026-07-24T10:00:00Z",
      "updated_at" => "2026-07-24T10:00:00Z"
    }

    second = %{
      "id" => second_id,
      "name" => "before sleep",
      "normalized_name" => normalized,
      "created_at" => "2026-07-24T10:01:00Z",
      "updated_at" => "2026-07-24T10:01:00Z"
    }

    assert {:ok, %{status: :accepted, effect: %{"entity_id" => ^first_id}}} =
             put_entity(context, 1, "user_tag", first, 0)

    assert {:ok,
            %{
              status: :accepted,
              effect: %{
                "entity_type" => "user_tag",
                "entity_id" => ^first_id,
                "state" => "active",
                "document" => %{"id" => ^first_id, "normalized_name" => ^normalized}
              }
            }} = put_entity(context, 2, "user_tag", second, 0)

    refute first_id == second_id

    refute Repo.get_by(EntityRecord,
             user_id: context.scope.user.id,
             entity_type: "user_tag",
             entity_id: second_id
           )
  end

  test "dhikr_tag_assignment accepts owned custom and built-in dhikrs and rejects foreign ones",
       context do
    fixture =
      "../contracts/progress-model/v1/fixtures/progress-state.json"
      |> File.read!()
      |> Jason.decode!()

    custom =
      fixture["dhikrs"]
      |> Enum.find(& &1["is_custom"])
      |> Map.put("id", Ecto.UUID.generate())

    builtin_id =
      "../contracts/progress-model/v1/builtin-dhikrs.json"
      |> File.read!()
      |> Jason.decode!()
      |> Map.fetch!("dhikrs")
      |> hd()
      |> Map.fetch!("id")

    assert {:ok, %{status: :accepted}} = put_entity(context, 1, "custom_dhikr", custom, 0)

    tag = tag_document(Ecto.UUID.generate(), "Travel")
    assert {:ok, %{status: :accepted}} = put_entity(context, 2, "user_tag", tag, 0)

    custom_assignment = %{
      "id" => Ecto.UUID.generate(),
      "tag_id" => tag["id"],
      "dhikr_id" => custom["id"],
      "created_at" => "2026-07-24T10:00:00Z"
    }

    builtin_assignment = %{
      "id" => Ecto.UUID.generate(),
      "tag_id" => tag["id"],
      "dhikr_id" => builtin_id,
      "created_at" => "2026-07-24T10:00:00Z"
    }

    foreign_assignment = %{
      "id" => Ecto.UUID.generate(),
      "tag_id" => tag["id"],
      "dhikr_id" => Ecto.UUID.generate(),
      "created_at" => "2026-07-24T10:00:00Z"
    }

    assert {:ok, %{status: :accepted}} =
             put_entity(context, 3, "dhikr_tag_assignment", custom_assignment, 0)

    assert {:ok, %{status: :accepted}} =
             put_entity(context, 4, "dhikr_tag_assignment", builtin_assignment, 0)

    assert {:ok, %{status: :invalid}} =
             put_entity(context, 5, "dhikr_tag_assignment", foreign_assignment, 0)
  end

  test "dhikr_tag_assignment updates reject mutated tag_id or dhikr_id references", context do
    tag_a = tag_document(Ecto.UUID.generate(), "Travel")
    tag_b = tag_document(Ecto.UUID.generate(), "Family")
    assert {:ok, %{status: :accepted}} = put_entity(context, 1, "user_tag", tag_a, 0)
    assert {:ok, %{status: :accepted}} = put_entity(context, 2, "user_tag", tag_b, 0)

    builtin_id =
      "../contracts/progress-model/v1/builtin-dhikrs.json"
      |> File.read!()
      |> Jason.decode!()
      |> Map.fetch!("dhikrs")
      |> hd()
      |> Map.fetch!("id")

    assignment_id = Ecto.UUID.generate()

    assignment = %{
      "id" => assignment_id,
      "tag_id" => tag_a["id"],
      "dhikr_id" => builtin_id,
      "created_at" => "2026-07-24T10:00:00Z"
    }

    assert {:ok, %{status: :accepted}} =
             put_entity(context, 3, "dhikr_tag_assignment", assignment, 0)

    swapped = %{assignment | "tag_id" => tag_b["id"]}

    assert {:ok, %{status: :invalid}} =
             put_entity(context, 4, "dhikr_tag_assignment", swapped, 1)

    stored =
      Repo.get_by!(EntityRecord,
        user_id: context.scope.user.id,
        entity_type: "dhikr_tag_assignment",
        entity_id: assignment_id
      )

    assert stored.document["tag_id"] == tag_a["id"]
    assert stored.version == 1
  end

  test "deleting a user_tag cascades assignment tombstones at the same revision", context do
    tag = tag_document(Ecto.UUID.generate(), "Sleep")
    assert {:ok, %{status: :accepted}} = put_entity(context, 1, "user_tag", tag, 0)

    builtin_id =
      "../contracts/progress-model/v1/builtin-dhikrs.json"
      |> File.read!()
      |> Jason.decode!()
      |> Map.fetch!("dhikrs")
      |> hd()
      |> Map.fetch!("id")

    assignment = %{
      "id" => Ecto.UUID.generate(),
      "tag_id" => tag["id"],
      "dhikr_id" => builtin_id,
      "created_at" => "2026-07-24T10:00:00Z"
    }

    assert {:ok, %{status: :accepted}} =
             put_entity(context, 2, "dhikr_tag_assignment", assignment, 0)

    assert {:ok, %{status: :accepted, revision: revision, effect: %{"state" => "deleted"}}} =
             lifecycle(context, 3, "entity_delete", "user_tag", tag["id"], 1)

    assignment_row =
      Repo.get_by!(EntityRecord,
        user_id: context.scope.user.id,
        entity_type: "dhikr_tag_assignment",
        entity_id: assignment["id"]
      )

    assert assignment_row.state == "deleted"
    assert assignment_row.sync_revision == revision
  end

  test "entity_restore of dhikr_tag_assignment revalidates tag and dhikr ownership", context do
    tag = tag_document(Ecto.UUID.generate(), "Sleep")
    assert {:ok, %{status: :accepted}} = put_entity(context, 1, "user_tag", tag, 0)

    builtin_id =
      "../contracts/progress-model/v1/builtin-dhikrs.json"
      |> File.read!()
      |> Jason.decode!()
      |> Map.fetch!("dhikrs")
      |> hd()
      |> Map.fetch!("id")

    assignment = %{
      "id" => Ecto.UUID.generate(),
      "tag_id" => tag["id"],
      "dhikr_id" => builtin_id,
      "created_at" => "2026-07-24T10:00:00Z"
    }

    assert {:ok, %{status: :accepted}} =
             put_entity(context, 2, "dhikr_tag_assignment", assignment, 0)

    assert {:ok, %{status: :accepted}} =
             lifecycle(context, 3, "entity_delete", "user_tag", tag["id"], 1)

    assignment_row =
      Repo.get_by!(EntityRecord,
        user_id: context.scope.user.id,
        entity_type: "dhikr_tag_assignment",
        entity_id: assignment["id"]
      )

    assert assignment_row.state == "deleted"

    assert {:ok, %{status: :invalid}} =
             lifecycle(
               context,
               4,
               "entity_restore",
               "dhikr_tag_assignment",
               assignment["id"],
               assignment_row.version
             )

    refute Repo.get_by(EntityRecord,
             user_id: context.scope.user.id,
             entity_type: "dhikr_tag_assignment",
             entity_id: assignment["id"],
             state: "active"
           )
  end

  test "deleting a custom_dhikr cascades its assignment tombstones after goal checks", context do
    fixture =
      "../contracts/progress-model/v1/fixtures/progress-state.json"
      |> File.read!()
      |> Jason.decode!()

    custom =
      fixture["dhikrs"]
      |> Enum.find(& &1["is_custom"])
      |> Map.put("id", Ecto.UUID.generate())

    assert {:ok, %{status: :accepted}} = put_entity(context, 1, "custom_dhikr", custom, 0)

    tag = tag_document(Ecto.UUID.generate(), "Bedtime")
    assert {:ok, %{status: :accepted}} = put_entity(context, 2, "user_tag", tag, 0)

    assignment = %{
      "id" => Ecto.UUID.generate(),
      "tag_id" => tag["id"],
      "dhikr_id" => custom["id"],
      "created_at" => "2026-07-24T10:00:00Z"
    }

    assert {:ok, %{status: :accepted}} =
             put_entity(context, 3, "dhikr_tag_assignment", assignment, 0)

    assert {:ok, %{status: :accepted, revision: revision}} =
             lifecycle(context, 4, "entity_delete", "custom_dhikr", custom["id"], 1)

    assignment_row =
      Repo.get_by!(EntityRecord,
        user_id: context.scope.user.id,
        entity_type: "dhikr_tag_assignment",
        entity_id: assignment["id"]
      )

    assert assignment_row.state == "deleted"
    assert assignment_row.sync_revision == revision

    tag_row =
      Repo.get_by!(EntityRecord,
        user_id: context.scope.user.id,
        entity_type: "user_tag",
        entity_id: tag["id"]
      )

    assert tag_row.state == "active"
  end

  test "transfers omit tag entities unless the client advertises dhikr_tags_v1", context do
    tag = tag_document(Ecto.UUID.generate(), "Family")
    assert {:ok, %{status: :accepted}} = put_entity(context, 1, "user_tag", tag, 0)

    builtin_id =
      "../contracts/progress-model/v1/builtin-dhikrs.json"
      |> File.read!()
      |> Jason.decode!()
      |> Map.fetch!("dhikrs")
      |> hd()
      |> Map.fetch!("id")

    assignment = %{
      "id" => Ecto.UUID.generate(),
      "tag_id" => tag["id"],
      "dhikr_id" => builtin_id,
      "created_at" => "2026-07-24T10:00:00Z"
    }

    assert {:ok, %{status: :accepted}} =
             put_entity(context, 2, "dhikr_tag_assignment", assignment, 0)

    assert {:ok, legacy_session} = Transfer.start(context.scope, "snapshot")
    assert {:ok, legacy_page} = Transfer.page(context.scope, legacy_session["transfer_id"], 1)

    refute Enum.any?(
             legacy_page["records"],
             &(&1["kind"] in ["user_tag", "dhikr_tag_assignment"])
           )

    assert {:ok, capable_session} =
             Transfer.start(context.scope, "snapshot", nil, capabilities: ["dhikr_tags_v1"])

    assert {:ok, capable_page} = Transfer.page(context.scope, capable_session["transfer_id"], 1)

    kinds = Enum.map(capable_page["records"], & &1["kind"])
    assert "user_tag" in kinds
    assert "dhikr_tag_assignment" in kinds
  end

  test "transfer pages order records by the documented dependency precedence", context do
    fixture =
      "../contracts/progress-model/v1/fixtures/progress-state.json"
      |> File.read!()
      |> Jason.decode!()

    custom =
      fixture["dhikrs"]
      |> Enum.find(& &1["is_custom"])
      |> Map.put("id", Ecto.UUID.generate())

    tag = tag_document(Ecto.UUID.generate(), "Order")
    assert {:ok, %{status: :accepted}} = put_entity(context, 1, "user_tag", tag, 0)
    assert {:ok, %{status: :accepted}} = put_entity(context, 2, "custom_dhikr", custom, 0)

    assignment = %{
      "id" => Ecto.UUID.generate(),
      "tag_id" => tag["id"],
      "dhikr_id" => custom["id"],
      "created_at" => "2026-07-24T10:00:00Z"
    }

    assert {:ok, %{status: :accepted}} =
             put_entity(context, 3, "dhikr_tag_assignment", assignment, 0)

    assert {:ok, session} =
             Transfer.start(context.scope, "snapshot", nil, capabilities: ["dhikr_tags_v1"])

    assert {:ok, page} = Transfer.page(context.scope, session["transfer_id"], 1)
    kinds = Enum.map(page["records"], & &1["kind"])

    # Documented transfer dependency order:
    # custom_dhikr=0, user_tag=0, dhikr_tag_assignment=1, goal=2, ...
    assert Enum.find_index(kinds, &(&1 == "user_tag")) <
             Enum.find_index(kinds, &(&1 == "dhikr_tag_assignment"))

    assert Enum.find_index(kinds, &(&1 == "custom_dhikr")) <
             Enum.find_index(kinds, &(&1 == "dhikr_tag_assignment"))
  end

  test "capability-gated tag rows do not crowd non-tag entities out of transfer limits",
       context do
    previous = Application.get_env(:awrad_server, :progress_sync_max_transfer_records)
    Application.put_env(:awrad_server, :progress_sync_max_transfer_records, 1)

    on_exit(fn ->
      if is_nil(previous) do
        Application.delete_env(:awrad_server, :progress_sync_max_transfer_records)
      else
        Application.put_env(:awrad_server, :progress_sync_max_transfer_records, previous)
      end
    end)

    tag_a = tag_document(Ecto.UUID.generate(), "Crowder A")
    tag_b = tag_document(Ecto.UUID.generate(), "Crowder B")
    assert {:ok, %{status: :accepted}} = put_entity(context, 1, "user_tag", tag_a, 0)
    assert {:ok, %{status: :accepted}} = put_entity(context, 2, "user_tag", tag_b, 0)

    fixture =
      "../contracts/progress-model/v1/fixtures/progress-state.json"
      |> File.read!()
      |> Jason.decode!()

    custom =
      fixture["dhikrs"]
      |> Enum.find(& &1["is_custom"])
      |> Map.put("id", Ecto.UUID.generate())

    assert {:ok, %{status: :accepted}} = put_entity(context, 3, "custom_dhikr", custom, 0)

    assert {:ok, legacy_session} = Transfer.start(context.scope, "snapshot")
    assert {:ok, legacy_page} = Transfer.page(context.scope, legacy_session["transfer_id"], 1)

    refute Enum.any?(
             legacy_page["records"],
             &(&1["kind"] in ["user_tag", "dhikr_tag_assignment"])
           )

    assert Enum.any?(
             legacy_page["records"],
             &(&1["kind"] == "custom_dhikr" and &1["id"] == custom["id"])
           )

    assert is_binary(legacy_page["checksum"])

    # Capable clients intentionally include tag rows in the shared budget; when
    # that budget is exhausted they still get transfer_too_large rather than a
    # silently truncated non-tag page.
    assert {:error, :transfer_too_large} =
             Transfer.start(context.scope, "snapshot", nil, capabilities: ["dhikr_tags_v1"])
  end

  defp tag_document(id, name) do
    {:ok, display, normalized} = Document.normalize_tag_name(name)

    %{
      "id" => id,
      "name" => display,
      "normalized_name" => normalized,
      "created_at" => "2026-07-24T10:00:00Z",
      "updated_at" => "2026-07-24T10:00:00Z"
    }
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

  defp lifecycle(context, sequence, type, entity_type, entity_id, version) do
    ProgressSync.execute_progress_command(
      context.scope,
      command(context.actor, sequence, %{
        "type" => type,
        "entity_type" => entity_type,
        "entity_id" => entity_id,
        "base_version" => Integer.to_string(version),
        "entity_incarnation" => "1"
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
