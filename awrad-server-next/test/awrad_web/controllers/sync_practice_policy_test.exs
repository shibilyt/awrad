defmodule AwradWeb.SyncPracticePolicyTest do
  @moduledoc """
  The `practice_policy` entity (slice 3d) over HTTP, against
  contracts/api/paths/sync.yaml: applied, rejected with `entity_id_invalid`,
  `document_invalid` and `delete_not_allowed`, read back from the changes
  feed, and gone with the account. The rules themselves are the fixture
  runners' (`sync_receipts`, `practice_policy_validity`).
  """
  use AwradWeb.ConnCase, async: true

  import Awrad.AccountsFixtures
  import AwradWeb.Contract

  alias Awrad.Repo
  alias Awrad.Sync.Entity

  @policy %{
    "day_reset" => "maghrib",
    "calculation_method" => "karachi",
    "madhab" => "shafi",
    "week_start" => "monday",
    "hijri_corrections" => [%{"year" => 1448, "month" => 5, "offset_days" => -1}]
  }

  defp command(id, op, base_version, document \\ nil) do
    %{
      "command_id" => Awrad.UUIDv7.generate(),
      "entity_type" => "practice_policy",
      "entity_id" => id,
      "op" => op,
      "base_version" => base_version
    }
    |> then(&if(document, do: Map.put(&1, "document", document), else: &1))
  end

  defp post_commands(conn, grant, commands) do
    conn
    |> bearer_request(grant)
    |> put_req_header("x-awrad-account", grant.user.id)
    |> post(~p"/api/v1/sync/commands", Jason.encode!(%{commands: commands}))
  end

  defp get_changes(conn, grant) do
    conn
    |> bearer_request(grant)
    |> put_req_header("x-awrad-account", grant.user.id)
    |> get("/api/v1/sync/changes")
  end

  setup %{conn: conn} do
    user = user_fixture()
    %{user: user, grant: grant_fixture(user), conn: conn}
  end

  test "post_sync_commands applies a put on the account's ID, and list_sync_changes returns it",
       %{conn: conn, grant: grant, user: user} do
    create = command(user.id, "put", 0, @policy)
    update = command(user.id, "put", 1, %{@policy | "calculation_method" => "dubai"})

    body = conn |> post_commands(grant, [create, update]) |> assert_conforms("post_sync_commands")

    assert body["receipts"] == [
             %{
               "command_id" => create["command_id"],
               "status" => "applied",
               "version" => 1,
               "revision" => 1,
               "cascaded" => nil
             },
             %{
               "command_id" => update["command_id"],
               "status" => "applied",
               "version" => 2,
               "revision" => 2,
               "cascaded" => nil
             }
           ]

    page = conn |> get_changes(grant) |> assert_conforms("list_sync_changes")

    assert page["changes"] == [
             %{
               "entity_type" => "practice_policy",
               "entity_id" => user.id,
               "state" => "active",
               "version" => 2,
               "revision" => 2,
               "document" => %{@policy | "calculation_method" => "dubai"}
             }
           ]

    assert %{"next_after" => 2, "has_more" => false, "head_revision" => 2} = page
  end

  test "post_sync_commands rejects another ID, an invalid policy and a delete",
       %{conn: conn, grant: grant, user: user} do
    other_id = command(Awrad.UUIDv7.generate(), "put", 0, @policy)
    # Device context never reaches the server.
    invalid =
      command(user.id, "put", 0, Map.put(@policy, "location", %{"latitude" => 11.25}))

    create = command(user.id, "put", 0, @policy)
    delete = command(user.id, "delete", 1)

    body =
      conn
      |> post_commands(grant, [other_id, invalid, create, delete])
      |> assert_conforms("post_sync_commands")

    current = %{"version" => 1, "state" => "active", "document" => @policy}

    assert body["receipts"] == [
             %{
               "command_id" => other_id["command_id"],
               "status" => "rejected",
               "code" => "entity_id_invalid",
               "fields" => [%{"field" => "/entity_id", "code" => "mismatch"}],
               "current" => nil
             },
             %{
               "command_id" => invalid["command_id"],
               "status" => "rejected",
               "code" => "document_invalid",
               "fields" => [%{"field" => "/document/location", "code" => "not_allowed"}],
               "current" => nil
             },
             %{
               "command_id" => create["command_id"],
               "status" => "applied",
               "version" => 1,
               "revision" => 1,
               "cascaded" => nil
             },
             %{
               "command_id" => delete["command_id"],
               "status" => "rejected",
               "code" => "delete_not_allowed",
               "fields" => [],
               "current" => current
             }
           ]

    assert body["head_revision"] == 1
    assert [%Entity{entity_id: id}] = Repo.all(Entity)
    assert id == user.id
  end

  test "the range error reaches the receipt under /document",
       %{conn: conn, grant: grant, user: user} do
    # 1447/10 one day later makes 1447/9 31 days long.
    put =
      command(user.id, "put", 0, %{
        @policy
        | "hijri_corrections" => [%{"year" => 1447, "month" => 10, "offset_days" => 1}]
      })

    body = conn |> post_commands(grant, [put]) |> assert_conforms("post_sync_commands")

    assert [%{"code" => "document_invalid", "fields" => fields}] = body["receipts"]
    assert fields == [%{"field" => "/document/hijri_corrections", "code" => "range"}]
  end

  test "deleting the account deletes its practice policy", %{conn: conn, grant: grant, user: user} do
    conn |> post_commands(grant, [command(user.id, "put", 0, @policy)]) |> json_response(200)
    assert Repo.aggregate(Entity, :count) == 1

    conn
    |> bearer_request(grant)
    |> post(~p"/api/v1/account/delete", Jason.encode!(%{current_password: valid_password()}))
    |> response(204)

    for table <- ~w(sync_heads sync_entities sync_receipts) do
      assert %{rows: [[0]]} = Repo.query!("SELECT count(*) FROM #{table}")
    end
  end
end
