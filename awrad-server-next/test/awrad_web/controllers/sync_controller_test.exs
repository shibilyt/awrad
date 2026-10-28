defmodule AwradWeb.SyncControllerTest do
  @moduledoc """
  `post_sync_commands` and `list_sync_changes` over HTTP, against
  contracts/api/paths/sync.yaml: both credentials (each on its own),
  `X-Awrad-Account`, batch envelope errors, and receipts and pages. The
  protocol rules themselves are the fixture runners' (test/awrad/sync/).
  """
  use AwradWeb.ConnCase, async: true

  import Awrad.AccountsFixtures
  import AwradWeb.Contract

  alias Awrad.Repo
  alias Awrad.Sync.{Entity, Receipt}

  @builtin "6f04f77e-dcb6-4a29-9dc5-fcd3649c2961"

  @dhikr %{
    "kind" => "dhikr",
    "arabic" => "سُبْحَانَ ٱللَّهِ",
    "title" => %{"en" => "Subhanallah", "ar" => nil, "ml" => nil},
    "transliteration" => %{"en" => "Subhanallah", "ml" => nil},
    "translation" => %{"en" => "Glory be to Allah", "ar" => nil, "ml" => nil},
    "audio" => %{"local_only" => true},
    "references" => [
      %{"id" => "quran", "type" => "quran", "surah" => 9, "ayah_start" => 129, "ayah_end" => 129}
    ]
  }

  defp put(type, id, base_version, document) do
    %{
      "command_id" => Awrad.UUIDv7.generate(),
      "entity_type" => type,
      "entity_id" => id,
      "op" => "put",
      "base_version" => base_version,
      "document" => document
    }
  end

  defp tag(id, name),
    do: put("user_tag", id, 0, %{"name" => name, "normalized_name" => String.downcase(name)})

  defp bearer(conn, grant, account \\ :own) do
    conn
    |> bearer_request(grant)
    |> account_header(account, grant.user.id)
  end

  defp account_header(conn, :own, user_id), do: put_req_header(conn, "x-awrad-account", user_id)
  defp account_header(conn, :none, _user_id), do: conn
  defp account_header(conn, value, _user_id), do: put_req_header(conn, "x-awrad-account", value)

  defp post_commands(conn, commands),
    do: post(conn, ~p"/api/v1/sync/commands", Jason.encode!(%{commands: commands}))

  defp get_changes(conn, query \\ ""), do: get(conn, "/api/v1/sync/changes" <> query)

  setup %{conn: conn} do
    user = user_fixture()
    %{user: user, grant: grant_fixture(user), conn: conn}
  end

  describe "post_sync_commands" do
    test "200: one receipt per command, in order, and the head revision",
         %{conn: conn, grant: grant} do
      dhikr_id = Awrad.UUIDv7.generate()
      morning = Awrad.UUIDv7.generate()
      duplicate_morning = Awrad.UUIDv7.generate()
      create = put("custom_dhikr", dhikr_id, 0, @dhikr)

      commands = [
        create,
        tag(morning, "Morning"),
        tag(duplicate_morning, "MORNING"),
        put("dhikr_personal", dhikr_id, 0, %{"tag_ids" => [duplicate_morning]}),
        put("custom_dhikr", dhikr_id, 0, @dhikr),
        put("user_tag", Awrad.UUIDv7.generate(), 0, %{
          "name" => "Night",
          "normalized_name" => "Night"
        }),
        create
      ]

      conn = conn |> bearer(grant) |> post_commands(commands)
      body = assert_conforms(conn, "post_sync_commands")

      assert Enum.map(body["receipts"], & &1["status"]) ==
               ~w(applied applied merged applied conflict rejected duplicate)

      assert Enum.map(body["receipts"], & &1["command_id"]) ==
               Enum.map(commands, & &1["command_id"])

      assert body["head_revision"] == 3
      assert Enum.at(body["receipts"], 2)["merged_into"] == morning
      assert get_resp_header(conn, "cache-control") == ["no-store"]

      personal = Repo.get_by!(Entity, entity_type: "dhikr_personal", entity_id: dhikr_id)
      assert personal.document == %{"tag_ids" => [morning]}
    end

    test "200: a delete's applied receipt lists its cascades, other applied receipts carry null",
         %{conn: conn, grant: grant} do
      dhikr_id = Awrad.UUIDv7.generate()
      morning = Awrad.UUIDv7.generate()
      night = Awrad.UUIDv7.generate()

      delete = fn type, id, base_version ->
        %{
          "command_id" => Awrad.UUIDv7.generate(),
          "entity_type" => type,
          "entity_id" => id,
          "op" => "delete",
          "base_version" => base_version
        }
      end

      commands = [
        put("custom_dhikr", dhikr_id, 0, @dhikr),
        tag(morning, "Morning"),
        tag(night, "Night"),
        put("dhikr_personal", dhikr_id, 0, %{"tag_ids" => [morning]}),
        put("dhikr_personal", @builtin, 0, %{"tag_ids" => [morning]}),
        delete.("user_tag", morning, 1),
        delete.("user_tag", night, 1),
        delete.("custom_dhikr", dhikr_id, 1)
      ]

      conn = conn |> bearer(grant) |> post_commands(commands)
      body = assert_conforms(conn, "post_sync_commands")

      assert Enum.map(body["receipts"], &{&1["status"], &1["revision"]}) ==
               Enum.map(1..8, &{"applied", &1})

      assert body["receipts"] |> Enum.take(5) |> Enum.map(& &1["cascaded"]) ==
               [nil, nil, nil, nil, nil]

      [tag_delete, unused_tag_delete, dhikr_delete] = Enum.drop(body["receipts"], 5)

      # Ordered by entity_type, then entity_id.
      assert tag_delete["cascaded"] ==
               for(
                 id <- Enum.sort([dhikr_id, @builtin]),
                 do: %{
                   "entity_type" => "dhikr_personal",
                   "entity_id" => id,
                   "state" => "active",
                   "version" => 2,
                   "revision" => 6
                 }
               )

      assert unused_tag_delete["cascaded"] == []

      assert dhikr_delete["cascaded"] == [
               %{
                 "entity_type" => "dhikr_personal",
                 "entity_id" => dhikr_id,
                 "state" => "deleted",
                 "version" => 3,
                 "revision" => 8
               }
             ]
    end

    test "200 for a browser with its cookie session and CSRF token", %{conn: conn, user: user} do
      {browser, csrf} = sign_in_browser(conn, user)

      conn =
        browser
        |> browser_request(csrf)
        |> put_req_header("x-awrad-account", user.id)
        |> post_commands([put("dhikr_personal", @builtin, 0, %{"tag_ids" => []})])

      assert [%{"status" => "applied"}] = assert_conforms(conn, "post_sync_commands")["receipts"]
    end

    test "Idempotency-Key is accepted and ignored", %{conn: conn, grant: grant} do
      key = Awrad.UUIDv7.generate()

      for name <- ["One", "Two"] do
        conn =
          conn
          |> bearer(grant)
          |> put_req_header("idempotency-key", key)
          |> post_commands([tag(Awrad.UUIDv7.generate(), name)])

        assert [%{"status" => "applied"}] =
                 assert_conforms(conn, "post_sync_commands")["receipts"]
      end
    end

    test "403 csrf_token_invalid for a cookie session without the CSRF token",
         %{conn: conn, user: user} do
      {browser, _csrf} = sign_in_browser(conn, user)

      conn =
        browser
        |> next_request()
        |> json_conn([{"x-awrad-account", user.id}])
        |> post_commands([tag(Awrad.UUIDv7.generate(), "Morning")])

      assert assert_conforms(conn, "post_sync_commands")["code"] == "csrf_token_invalid"
      assert Repo.aggregate(Receipt, :count) == 0
    end

    test "401 unauthenticated without a credential, or with a bad bearer next to a valid cookie",
         %{conn: conn, user: user} do
      anonymous =
        conn
        |> json_conn([{"x-awrad-account", user.id}])
        |> post_commands([tag(Awrad.UUIDv7.generate(), "Morning")])

      assert assert_conforms(anonymous, "post_sync_commands")["code"] == "unauthenticated"

      {browser, csrf} = sign_in_browser(conn, user)

      mixed =
        browser
        |> browser_request(csrf)
        |> put_req_header("authorization", "Bearer not-a-token")
        |> put_req_header("x-awrad-account", user.id)
        |> post_commands([tag(Awrad.UUIDv7.generate(), "Morning")])

      assert assert_conforms(mixed, "post_sync_commands")["code"] == "unauthenticated"
    end

    test "409 account_mismatch for another account, with nothing written",
         %{conn: conn, grant: grant} do
      other = user_fixture()

      conn =
        conn
        |> bearer(grant, other.id)
        |> post_commands([tag(Awrad.UUIDv7.generate(), "Morning")])

      assert assert_conforms(conn, "post_sync_commands")["code"] == "account_mismatch"
      assert conn.status == 409
      assert Repo.aggregate(Receipt, :count) == 0
    end

    test "400 malformed_request for a missing or malformed X-Awrad-Account, or a bad body",
         %{conn: conn, grant: grant} do
      commands = [tag(Awrad.UUIDv7.generate(), "Morning")]

      for account <- [:none, "not-an-id", String.upcase(grant.user.id)] do
        response = conn |> bearer(grant, account) |> post_commands(commands)
        assert assert_conforms(response, "post_sync_commands")["code"] == "malformed_request"
      end

      for body <- [%{commands: "x"}, %{}, %{commands: commands, extra: 1}, [commands]] do
        response = conn |> bearer(grant) |> post(~p"/api/v1/sync/commands", Jason.encode!(body))
        assert assert_conforms(response, "post_sync_commands")["code"] == "malformed_request"
      end
    end

    test "422 validation_failed for a batch of 0 or more than 100 commands",
         %{conn: conn, grant: grant} do
      for commands <- [[], for(n <- 0..100, do: tag(Awrad.UUIDv7.generate(), "Tag #{n}"))] do
        conn = conn |> bearer(grant) |> post_commands(commands)
        body = assert_conforms(conn, "post_sync_commands")
        assert body["code"] == "validation_failed"
        assert [%{"field" => "/commands", "code" => "batch_size_invalid"}] = body["errors"]
      end

      assert Repo.aggregate(Receipt, :count) == 0
    end

    test "422 validation_failed for a malformed command, with nothing applied",
         %{conn: conn, grant: grant} do
      good = tag(Awrad.UUIDv7.generate(), "Morning")
      delete = %{put("custom_dhikr", Awrad.UUIDv7.generate(), 1, %{}) | "op" => "delete"}

      commands = [
        good,
        "not a command",
        %{good | "command_id" => "ABC"} |> Map.put("extra", true),
        %{good | "entity_type" => "goal", "op" => "patch", "base_version" => -1},
        %{good | "document" => []},
        Map.delete(good, "document"),
        delete
      ]

      conn = conn |> bearer(grant) |> post_commands(commands)
      body = assert_conforms(conn, "post_sync_commands")

      assert Enum.map(body["errors"], &{&1["field"], &1["code"]}) == [
               {"/commands/1", "command_malformed"},
               {"/commands/2/extra", "command_malformed"},
               {"/commands/2/command_id", "command_malformed"},
               {"/commands/3/entity_type", "command_malformed"},
               {"/commands/3/op", "command_malformed"},
               {"/commands/3/base_version", "command_malformed"},
               {"/commands/4/document", "command_malformed"},
               {"/commands/5/document", "command_malformed"},
               {"/commands/6/document", "command_malformed"}
             ]

      assert Repo.aggregate(Receipt, :count) == 0
    end
  end

  describe "list_sync_changes" do
    setup %{conn: conn, grant: grant} do
      tag_id = Awrad.UUIDv7.generate()

      conn
      |> bearer(grant)
      |> post_commands([
        tag(tag_id, "Morning"),
        put("dhikr_personal", @builtin, 0, %{"tag_ids" => [tag_id]}),
        %{
          "command_id" => Awrad.UUIDv7.generate(),
          "entity_type" => "user_tag",
          "entity_id" => tag_id,
          "op" => "delete",
          "base_version" => 1
        }
      ])
      |> json_response(200)

      %{tag_id: tag_id}
    end

    test "200: after=0 lists active entities; after>0 includes deletes",
         %{conn: conn, grant: grant, tag_id: tag_id} do
      full = conn |> bearer(grant) |> get_changes() |> assert_conforms("list_sync_changes")

      assert full["changes"] == [
               %{
                 "entity_type" => "dhikr_personal",
                 "entity_id" => @builtin,
                 "state" => "active",
                 "version" => 2,
                 "revision" => 3,
                 "document" => %{"tag_ids" => []}
               }
             ]

      assert %{"next_after" => 3, "has_more" => false, "head_revision" => 3} = full

      delta =
        conn
        |> bearer(grant)
        |> get_changes("?after=2&limit=1")
        |> assert_conforms("list_sync_changes")

      assert Enum.map(delta["changes"], &{&1["entity_type"], &1["entity_id"], &1["state"]}) == [
               {"dhikr_personal", @builtin, "active"},
               {"user_tag", tag_id, "deleted"}
             ]

      assert hd(tl(delta["changes"]))["document"] == nil
    end

    test "200 for a browser with its cookie session (no CSRF needed to read)",
         %{conn: conn, user: user} do
      {browser, _csrf} = sign_in_browser(conn, user)

      conn =
        browser
        |> next_request()
        |> put_req_header("x-awrad-account", user.id)
        |> get_changes()

      assert assert_conforms(conn, "list_sync_changes")["head_revision"] == 3
    end

    test "400 malformed_request for a bad after or limit, or no X-Awrad-Account",
         %{conn: conn, grant: grant} do
      for query <- [
            "?after=-1",
            "?after=x",
            "?after=9007199254740992",
            "?limit=0",
            "?limit=501",
            "?limit=1.5"
          ] do
        response = conn |> bearer(grant) |> get_changes(query)
        assert assert_conforms(response, "list_sync_changes")["code"] == "malformed_request"
      end

      response = conn |> bearer(grant, :none) |> get_changes()
      assert assert_conforms(response, "list_sync_changes")["code"] == "malformed_request"
    end

    test "401 unauthenticated without a credential", %{conn: conn, user: user} do
      conn = conn |> put_req_header("x-awrad-account", user.id) |> get_changes()
      assert assert_conforms(conn, "list_sync_changes")["code"] == "unauthenticated"
    end

    test "409 account_mismatch for another account", %{conn: conn, grant: grant} do
      conn = conn |> bearer(grant, user_fixture().id) |> get_changes()
      assert assert_conforms(conn, "list_sync_changes")["code"] == "account_mismatch"
    end
  end

  test "deleting the account deletes its sync data", %{conn: conn, grant: grant} do
    conn |> bearer(grant) |> post_commands([tag(Awrad.UUIDv7.generate(), "Morning")])

    conn
    |> bearer_request(grant)
    |> post(~p"/api/v1/account/delete", Jason.encode!(%{current_password: valid_password()}))
    |> response(204)

    for table <- ~w(sync_heads sync_entities sync_receipts sync_tag_aliases) do
      assert %{rows: [[0]]} = Repo.query!("SELECT count(*) FROM #{table}")
    end
  end
end
