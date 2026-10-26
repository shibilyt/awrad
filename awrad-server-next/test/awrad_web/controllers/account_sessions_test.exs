defmodule AwradWeb.AccountSessionsTest do
  @moduledoc """
  The session list, revoking one session and revoking the others, against
  contracts/api/paths/account_settings.yaml (slice 2b), with both credentials.
  """
  use AwradWeb.ConnCase, async: true

  import Awrad.AccountsFixtures
  import AwradWeb.Contract
  import Ecto.Query

  alias Awrad.Accounts.{DeviceSession, UserToken}
  alias Awrad.Repo
  alias AwradWeb.UserAuth

  @firefox {"user-agent",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:131.0) Gecko/20100101 Firefox/131.0"}
  @safari {"user-agent",
           "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 " <>
             "(KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"}

  defp ago(minutes), do: DateTime.add(DateTime.utc_now(:second), -minutes, :minute)

  defp seen(DeviceSession, id, minutes_ago),
    do: Repo.update_all(where_id(DeviceSession, id), set: [last_seen_at: ago(minutes_ago)])

  defp seen(UserToken, id, minutes_ago),
    do: Repo.update_all(where_id(UserToken, id), set: [last_seen_at: ago(minutes_ago)])

  defp where_id(schema, id), do: from(s in schema, where: s.id == ^id)

  defp only_browser_session_id(user),
    do: Repo.one!(from(t in UserToken, where: t.user_id == ^user.id, select: t.id))

  defp list(request, query \\ ""), do: get(request, "/api/v1/account/sessions" <> query)

  defp me(request), do: get(request, ~p"/api/v1/account")

  describe "list_account_sessions" do
    setup %{conn: conn} do
      user = user_fixture()
      phone = grant_fixture(user)
      tablet = grant_fixture(user, device(%{name: "iPad", platform: :ios}))
      {browser, csrf} = sign_in_browser(conn, user, [@firefox])
      browser_id = only_browser_session_id(user)

      seen(DeviceSession, phone.session.id, 60)
      seen(DeviceSession, tablet.session.id, 120)
      seen(UserToken, browser_id, 30)

      %{
        user: user,
        phone: phone,
        tablet: tablet,
        browser: browser,
        csrf: csrf,
        browser_id: browser_id
      }
    end

    test "both kinds, most recently used first, the bearer caller marked", ctx do
      conn = ctx.conn |> bearer_request(ctx.phone) |> list()

      body = assert_conforms(conn, "list_account_sessions")
      assert conn.status == 200
      assert body["next_cursor"] == nil

      # The request itself refreshed the caller's last_seen_at (an hour old).
      assert Enum.map(body["items"], &{&1["id"], &1["kind"], &1["is_current"]}) == [
               {ctx.phone.session.id, "device", true},
               {ctx.browser_id, "browser", false},
               {ctx.tablet.session.id, "device", false}
             ]

      [phone, browser, tablet] = body["items"]
      assert %{"name" => "Firefox on Windows", "platform" => "web"} = browser
      assert %{"name" => "Pixel 9", "platform" => "android"} = phone
      assert %{"name" => "iPad", "platform" => "ios"} = tablet
    end

    test "the cookie caller is marked", ctx do
      conn = ctx.browser |> browser_request(ctx.csrf) |> list()

      body = assert_conforms(conn, "list_account_sessions")

      assert [%{"id" => id, "is_current" => true}] =
               Enum.filter(body["items"], & &1["is_current"])

      assert id == ctx.browser_id
    end

    test "only the account's live sessions", ctx do
      other = user_fixture()
      grant_fixture(other)
      Awrad.Accounts.generate_user_session_token(other)

      Repo.update_all(where_id(DeviceSession, ctx.tablet.session.id),
        set: [revoked_at: DateTime.utc_now(:second), revoke_reason: "revoked"]
      )

      expired = grant_fixture(ctx.user)

      Repo.update_all(where_id(DeviceSession, expired.session.id),
        set: [idle_expires_at: ago(1)]
      )

      stale = Awrad.Accounts.generate_user_session_token(ctx.user)

      Repo.update_all(where(UserToken, token: ^stale),
        set: [inserted_at: DateTime.add(DateTime.utc_now(:second), -15, :day)]
      )

      body =
        ctx.conn
        |> bearer_request(ctx.phone)
        |> list()
        |> assert_conforms("list_account_sessions")

      assert Enum.map(body["items"], & &1["id"]) == [ctx.phone.session.id, ctx.browser_id]
    end

    test "an unknown browser has a null name", ctx do
      {_browser, _csrf} = sign_in_browser(build_conn(), ctx.user, [{"user-agent", "curl/8.7.1"}])

      body =
        ctx.conn
        |> bearer_request(ctx.phone)
        |> list()
        |> assert_conforms("list_account_sessions")

      assert Enum.count(body["items"], &(&1["kind"] == "browser" and &1["name"] == nil)) == 1
    end

    test "pages with an opaque cursor, without gaps or repeats", ctx do
      {_safari, _csrf} = sign_in_browser(build_conn(), ctx.user, [@safari])

      pages =
        Stream.unfold("?limit=2", fn
          nil ->
            nil

          query ->
            body =
              ctx.conn
              |> bearer_request(ctx.phone)
              |> list(query)
              |> assert_conforms("list_account_sessions")

            next = body["next_cursor"] && "?limit=2&cursor=" <> body["next_cursor"]
            {body["items"], next}
        end)
        |> Enum.to_list()

      assert Enum.map(pages, &length/1) == [2, 2]
      ids = pages |> List.flatten() |> Enum.map(& &1["id"])

      all =
        ctx.conn
        |> bearer_request(ctx.phone)
        |> list()
        |> assert_conforms("list_account_sessions")

      assert ids == Enum.map(all["items"], & &1["id"])
    end

    test "400 for a bad limit or cursor", ctx do
      for query <- [
            "?limit=0",
            "?limit=101",
            "?limit=ten",
            "?cursor=",
            "?cursor=bm90LWEtY3Vyc29y"
          ] do
        conn = ctx.conn |> bearer_request(ctx.phone) |> list(query)
        assert assert_conforms(conn, "list_account_sessions")["code"] == "malformed_request"
      end
    end

    test "401 without a credential, or with a bad bearer even beside a good cookie", ctx do
      conn = list(ctx.conn)
      assert assert_conforms(conn, "list_account_sessions")["code"] == "unauthenticated"

      conn =
        ctx.browser
        |> browser_request(ctx.csrf)
        |> put_req_header("authorization", "Bearer nope")
        |> list()

      assert assert_conforms(conn, "list_account_sessions")["code"] == "unauthenticated"
    end
  end

  describe "revoke_account_session" do
    setup %{conn: conn} do
      user = user_fixture()
      phone = grant_fixture(user)
      other_phone = grant_fixture(user)
      {browser, csrf} = sign_in_browser(conn, user)
      %{user: user, phone: phone, other_phone: other_phone, browser: browser, csrf: csrf}
    end

    defp revoke(request, id), do: delete(request, "/api/v1/account/sessions/" <> id)

    test "a device ends another device: 204, and its token is then rejected", ctx do
      conn = ctx.conn |> bearer_request(ctx.phone) |> revoke(ctx.other_phone.session.id)

      assert assert_conforms(conn, "revoke_account_session") == nil
      assert conn.status == 204
      assert me(bearer_request(ctx.conn, ctx.other_phone)).status == 401
      assert me(bearer_request(ctx.conn, ctx.phone)).status == 200

      assert %DeviceSession{revoke_reason: "revoked"} =
               Repo.get!(DeviceSession, ctx.other_phone.session.id)
    end

    test "a device ends a browser", ctx do
      id = only_browser_session_id(ctx.user)
      conn = ctx.conn |> bearer_request(ctx.phone) |> revoke(id)

      assert assert_conforms(conn, "revoke_account_session") == nil
      assert ctx.browser |> browser_request(ctx.csrf) |> me() |> Map.get(:status) == 401
    end

    test "a browser ends a device, with its CSRF token", ctx do
      conn = ctx.browser |> browser_request(ctx.csrf) |> revoke(ctx.phone.session.id)

      assert assert_conforms(conn, "revoke_account_session") == nil
      assert me(bearer_request(ctx.conn, ctx.phone)).status == 401
      assert ctx.browser |> browser_request(ctx.csrf) |> me() |> Map.get(:status) == 200
    end

    test "revoking its own device session signs the device out", ctx do
      conn = ctx.conn |> bearer_request(ctx.phone) |> revoke(ctx.phone.session.id)

      assert assert_conforms(conn, "revoke_account_session") == nil
      assert me(bearer_request(ctx.conn, ctx.phone)).status == 401
      assert Repo.get!(DeviceSession, ctx.phone.session.id).revoke_reason == "signed_out"
    end

    test "revoking its own browser session signs the browser out and clears its cookies", ctx do
      id = only_browser_session_id(ctx.user)
      conn = ctx.browser |> browser_request(ctx.csrf) |> revoke(id)

      assert assert_conforms(conn, "revoke_account_session") == nil
      assert %{max_age: 0} = conn.resp_cookies[UserAuth.remember_me_cookie()]
      assert conn |> next_request() |> me() |> Map.get(:status) == 401
      assert ctx.browser |> browser_request(ctx.csrf) |> me() |> Map.get(:status) == 401
    end

    test "404 for another account's session, an ended one, or an unknown ID", ctx do
      stranger = grant_fixture(user_fixture())
      revoke(bearer_request(ctx.conn, ctx.phone), ctx.other_phone.session.id)

      for id <- [stranger.session.id, ctx.other_phone.session.id, Ecto.UUID.generate(), "nope"] do
        conn = ctx.conn |> bearer_request(ctx.phone) |> revoke(id)
        assert assert_conforms(conn, "revoke_account_session")["code"] == "not_found"
      end

      assert me(bearer_request(ctx.conn, stranger)).status == 200
    end

    test "403 for a cookie request without its CSRF token; 401 without a credential", ctx do
      conn =
        ctx.browser
        |> next_request()
        |> revoke(ctx.phone.session.id)

      assert assert_conforms(conn, "revoke_account_session")["code"] == "csrf_token_invalid"
      assert me(bearer_request(ctx.conn, ctx.phone)).status == 200

      conn = revoke(ctx.conn, ctx.phone.session.id)
      assert assert_conforms(conn, "revoke_account_session")["code"] == "unauthenticated"
    end
  end

  describe "revoke_other_account_sessions" do
    setup %{conn: conn} do
      user = user_fixture()
      phone = grant_fixture(user)
      other_phone = grant_fixture(user)
      {browser, csrf} = sign_in_browser(conn, user)
      {other_browser, other_csrf} = sign_in_browser(build_conn(), user)

      %{
        user: user,
        phone: phone,
        other_phone: other_phone,
        browser: browser,
        csrf: csrf,
        other_browser: other_browser,
        other_csrf: other_csrf
      }
    end

    defp revoke_others(request, headers \\ []),
      do: request |> json_conn(headers) |> post(~p"/api/v1/account/sessions/revoke_others")

    test "from a device: every other session ends, the caller stays", ctx do
      conn = ctx.conn |> bearer_request(ctx.phone) |> revoke_others()

      assert assert_conforms(conn, "revoke_other_account_sessions") == nil
      assert conn.status == 204
      assert me(bearer_request(ctx.conn, ctx.phone)).status == 200
      assert me(bearer_request(ctx.conn, ctx.other_phone)).status == 401
      assert ctx.browser |> browser_request(ctx.csrf) |> me() |> Map.get(:status) == 401

      assert ctx.other_browser |> browser_request(ctx.other_csrf) |> me() |> Map.get(:status) ==
               401
    end

    test "from a browser: every other session ends, the caller stays with its CSRF token", ctx do
      conn = ctx.browser |> browser_request(ctx.csrf) |> revoke_others()

      assert assert_conforms(conn, "revoke_other_account_sessions") == nil
      assert me(bearer_request(ctx.conn, ctx.phone)).status == 401

      assert ctx.other_browser |> browser_request(ctx.other_csrf) |> me() |> Map.get(:status) ==
               401

      again = ctx.browser |> browser_request(ctx.csrf) |> revoke_others()
      assert again.status == 204
    end

    test "a repeat with the same Idempotency-Key replays; another account's key is its own",
         ctx do
      key = Ecto.UUID.generate()
      first = ctx.conn |> bearer_request(ctx.phone) |> revoke_others([{"idempotency-key", key}])
      assert first.status == 204

      repeat = ctx.conn |> bearer_request(ctx.phone) |> revoke_others([{"idempotency-key", key}])
      assert assert_conforms(repeat, "revoke_other_account_sessions") == nil

      stranger = user_fixture()
      stranger_phone = grant_fixture(stranger)
      stranger_other = grant_fixture(stranger)

      conn =
        ctx.conn |> bearer_request(stranger_phone) |> revoke_others([{"idempotency-key", key}])

      assert conn.status == 204
      # Ran for the other account rather than replaying the first one's result.
      assert me(bearer_request(ctx.conn, stranger_other)).status == 401
    end

    test "403 without the CSRF token; 401 without a credential", ctx do
      conn = ctx.browser |> next_request() |> revoke_others()

      assert assert_conforms(conn, "revoke_other_account_sessions")["code"] ==
               "csrf_token_invalid"

      assert me(bearer_request(ctx.conn, ctx.phone)).status == 200

      conn = revoke_others(ctx.conn)
      assert assert_conforms(conn, "revoke_other_account_sessions")["code"] == "unauthenticated"
    end
  end
end
