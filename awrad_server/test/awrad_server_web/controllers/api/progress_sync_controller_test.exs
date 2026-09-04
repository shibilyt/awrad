defmodule AwradServerWeb.Api.ProgressSyncControllerTest do
  use AwradServerWeb.ConnCase, async: false

  import AwradServer.AccountsFixtures
  import Ecto.Query

  alias AwradServer.Accounts.Token
  alias AwradServer.ProgressSync.{Actor, CommandReceipt, EntityRecord, Head, TransferSession}
  alias AwradServer.Repo

  @header %{
    "protocol_version" => 1,
    "progress_model_version" => 1,
    "capabilities" => ["count_ledger", "entity_occ", "materialized_transfers"]
  }

  test "verified bearer user can push an entity and pull an immutable snapshot", %{conn: conn} do
    installation_id = Ecto.UUID.generate()
    {conn, _user} = authenticated_conn(conn, installation_id)
    actor_id = Ecto.UUID.generate()
    dhikr = custom_dhikr()

    pushed =
      post(conn, ~p"/api/sync/v1/progress/commands", %{
        "header" => @header,
        "installation_id" => installation_id,
        "commands" => [
          %{
            "type" => "entity_upsert",
            "command_id" => Ecto.UUID.generate(),
            "actor_id" => actor_id,
            "actor_sequence" => "1",
            "entity_type" => "custom_dhikr",
            "entity_id" => dhikr["id"],
            "base_version" => "0",
            "entity_incarnation" => "1",
            "proposed_document" => dhikr
          }
        ]
      })

    receipt = json_response(pushed, 200)["receipts"] |> hd()
    assert receipt["status"] == "accepted"
    assert receipt["result_revision"] == "1"

    snapshot =
      post(recycle(pushed), ~p"/api/sync/v1/progress/snapshots", %{
        "header" => @header,
        "kind" => "snapshot",
        "cursor" => nil
      })

    session = json_response(snapshot, 200)
    assert session["record_count"] == 1
    assert session["through_revision"] == "1"

    page =
      get(
        recycle(snapshot),
        ~p"/api/sync/v1/progress/snapshots/#{session["transfer_id"]}/pages/1"
      )

    [record] = json_response(page, 200)["records"]
    assert record["kind"] == "custom_dhikr"
    assert record["payload"]["document"]["title"] == dhikr["title"]
  end

  test "transfer pages cannot be read with another user's bearer token", %{conn: conn} do
    {owner_conn, _owner} = authenticated_conn(conn)

    snapshot =
      post(owner_conn, ~p"/api/sync/v1/progress/snapshots", %{
        "header" => @header,
        "kind" => "snapshot",
        "cursor" => nil
      })

    session_id = json_response(snapshot, 200)["transfer_id"]
    {other_conn, _other} = authenticated_conn(build_conn())

    denied =
      get(other_conn, ~p"/api/sync/v1/progress/snapshots/#{session_id}/pages/1")

    assert json_response(denied, 410)["error"] == "transfer_expired_or_missing"
  end

  test "capable clients get an unchanged delta without a materialized session", %{conn: conn} do
    {conn, user} = authenticated_conn(conn)

    snapshot =
      post(conn, ~p"/api/sync/v1/progress/snapshots", %{
        "header" => @header,
        "kind" => "snapshot",
        "cursor" => nil
      })

    cursor = json_response(snapshot, 200)["cursor"]
    sessions = from(session in TransferSession, where: session.user_id == ^user.id)
    before_count = Repo.aggregate(sessions, :count)

    capable_header =
      Map.update!(@header, "capabilities", &(&1 ++ ["unchanged_delta"]))

    delta =
      post(recycle(snapshot), ~p"/api/sync/v1/progress/deltas", %{
        "header" => capable_header,
        "kind" => "delta",
        "cursor" => cursor
      })

    body = json_response(delta, 200)
    assert body["status"] == "unchanged"
    assert body["kind"] == "delta"
    assert body["through_revision"] == "0"
    assert Repo.aggregate(sessions, :count) == before_count
    refute Map.has_key?(body, "transfer_id")
  end

  test "registered actor can acknowledge applied and safe revisions", %{conn: conn} do
    actor_id = Ecto.UUID.generate()
    installation_id = Ecto.UUID.generate()
    {conn, _user} = authenticated_conn(conn, installation_id)
    dhikr = custom_dhikr()

    pushed =
      post(conn, ~p"/api/sync/v1/progress/commands", %{
        "header" => @header,
        "installation_id" => installation_id,
        "commands" => [
          %{
            "type" => "entity_upsert",
            "command_id" => Ecto.UUID.generate(),
            "actor_id" => actor_id,
            "actor_sequence" => "1",
            "entity_type" => "custom_dhikr",
            "entity_id" => dhikr["id"],
            "base_version" => "0",
            "entity_incarnation" => "1",
            "proposed_document" => dhikr
          }
        ]
      })

    acknowledged =
      post(recycle(pushed), ~p"/api/sync/v1/progress/actors/ack", %{
        "header" => @header,
        "actor_id" => actor_id,
        "installation_id" => installation_id,
        "starting_sequence" => "2",
        "applied_revision" => "1",
        "safe_compaction_revision" => "1"
      })

    body = json_response(acknowledged, 200)
    assert body["actor_id"] == actor_id
    assert body["applied_revision"] == "1"
    assert body["safe_compaction_revision"] == "1"
  end

  test "a cloud-only client registers its actor when acknowledging", %{conn: conn} do
    actor_id = Ecto.UUID.generate()
    installation_id = Ecto.UUID.generate()
    {conn, _user} = authenticated_conn(conn, installation_id)

    acknowledged =
      post(conn, ~p"/api/sync/v1/progress/actors/ack", %{
        "header" => @header,
        "actor_id" => actor_id,
        "installation_id" => installation_id,
        "starting_sequence" => "1",
        "applied_revision" => "0",
        "safe_compaction_revision" => "0"
      })

    assert json_response(acknowledged, 200)["actor_id"] == actor_id
  end

  test "an expired acknowledgement actor can rotate without losing its durable sequence", %{
    conn: conn
  } do
    installation_id = Ecto.UUID.generate()
    actor_id = Ecto.UUID.generate()
    {conn, _user} = authenticated_conn(conn, installation_id)

    acknowledged =
      post(conn, ~p"/api/sync/v1/progress/actors/ack", %{
        "header" => @header,
        "actor_id" => actor_id,
        "installation_id" => installation_id,
        "starting_sequence" => "42",
        "applied_revision" => "0",
        "safe_compaction_revision" => "0"
      })

    assert json_response(acknowledged, 200)["actor_id"] == actor_id

    Repo.get!(Actor, actor_id)
    |> Ecto.Changeset.change(
      lease_expires_at: DateTime.add(DateTime.utc_now(:second), -1, :second)
    )
    |> Repo.update!()

    forked =
      post(recycle(acknowledged), ~p"/api/sync/v1/progress/actors/ack", %{
        "header" => @header,
        "actor_id" => actor_id,
        "installation_id" => installation_id,
        "starting_sequence" => "42",
        "applied_revision" => "0",
        "safe_compaction_revision" => "0"
      })

    assert json_response(forked, 409)["error"] == "actor_fork"

    replacement_id = Ecto.UUID.generate()

    recovered =
      post(recycle(forked), ~p"/api/sync/v1/progress/actors/ack", %{
        "header" => @header,
        "actor_id" => replacement_id,
        "installation_id" => installation_id,
        "starting_sequence" => "42",
        "applied_revision" => "0",
        "safe_compaction_revision" => "0"
      })

    assert json_response(recovered, 200)["actor_id"] == replacement_id
    assert %Actor{next_expected_sequence: 42, incarnation: 2} = Repo.get!(Actor, replacement_id)
  end

  test "sync routes reject unauthenticated requests", %{conn: conn} do
    denied =
      post(conn, ~p"/api/sync/v1/progress/snapshots", %{
        "header" => @header,
        "kind" => "snapshot",
        "cursor" => nil
      })

    assert json_response(denied, 401)["error"] == "unauthorized"
  end

  test "actor installation must match the authenticated device session", %{conn: conn} do
    {conn, _user} = authenticated_conn(conn, Ecto.UUID.generate())

    denied =
      post(conn, ~p"/api/sync/v1/progress/commands", %{
        "header" => @header,
        "installation_id" => Ecto.UUID.generate(),
        "commands" => [
          %{
            "type" => "increment",
            "command_id" => Ecto.UUID.generate(),
            "actor_id" => Ecto.UUID.generate(),
            "actor_sequence" => "1",
            "goal_id" => Ecto.UUID.generate(),
            "slot_id" => Ecto.UUID.generate(),
            "local_date" => "2026-07-16",
            "amount" => "1",
            "entity_incarnation" => "1"
          }
        ]
      })

    assert json_response(denied, 422)["error"] == "installation_mismatch"
  end

  test "a command batch rolls back atomically when a later sequence has a gap", %{conn: conn} do
    installation_id = Ecto.UUID.generate()
    actor_id = Ecto.UUID.generate()
    {conn, user} = authenticated_conn(conn, installation_id)
    dhikr = custom_dhikr()

    denied =
      post(conn, ~p"/api/sync/v1/progress/commands", %{
        "header" => @header,
        "installation_id" => installation_id,
        "commands" => [
          entity_upsert(actor_id, "1", dhikr),
          entity_upsert(actor_id, "3", Map.put(dhikr, "id", Ecto.UUID.generate()))
        ]
      })

    assert json_response(denied, 409)["error"] == "sequence_gap"
    assert Repo.aggregate(EntityRecord, :count) == 0
    assert Repo.aggregate(CommandReceipt, :count) == 0
    assert Repo.get!(Head, user.id).revision == 0
  end

  test "kill switch makes transfer pages retryable", %{conn: conn} do
    {conn, _user} = authenticated_conn(conn)
    previous = Application.get_env(:awrad_server, :progress_sync_enabled, true)
    Application.put_env(:awrad_server, :progress_sync_enabled, false)
    on_exit(fn -> Application.put_env(:awrad_server, :progress_sync_enabled, previous) end)

    denied = get(conn, ~p"/api/sync/v1/progress/snapshots/#{Ecto.UUID.generate()}/pages/1")
    assert json_response(denied, 503)["error"] == "sync_disabled"
  end

  defp authenticated_conn(conn, installation_id \\ Ecto.UUID.generate()) do
    user = user_fixture()

    {:ok, {_session, access, _refresh}} =
      Token.create_session(user, %{
        "installation_id" => installation_id,
        "name" => "Sync test",
        "platform" => "ios"
      })

    {put_req_header(conn, "authorization", "Bearer #{access}"), user}
  end

  defp custom_dhikr do
    fixture =
      "../contracts/progress-model/v1/fixtures/progress-state.json"
      |> File.read!()
      |> Jason.decode!()

    fixture["dhikrs"]
    |> Enum.find(& &1["is_custom"])
    |> Map.put("id", Ecto.UUID.generate())
  end

  defp entity_upsert(actor_id, sequence, document) do
    %{
      "type" => "entity_upsert",
      "command_id" => Ecto.UUID.generate(),
      "actor_id" => actor_id,
      "actor_sequence" => sequence,
      "entity_type" => "custom_dhikr",
      "entity_id" => document["id"],
      "base_version" => "0",
      "entity_incarnation" => "1",
      "proposed_document" => document
    }
  end
end
