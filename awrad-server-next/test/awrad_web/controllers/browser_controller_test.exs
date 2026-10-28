defmodule AwradWeb.BrowserControllerTest do
  @moduledoc "Browser CSRF token, sign-in and sign-out, against contracts/api/paths/browser.yaml."
  use AwradWeb.ConnCase, async: true

  import Awrad.AccountsFixtures
  import AwradWeb.Contract

  alias Awrad.Accounts.UserToken
  alias Awrad.Repo
  alias AwradWeb.UserAuth

  # An anonymous browser: its session cookie and CSRF token from get_browser_csrf_token.
  defp anonymous(conn) do
    conn = get(conn, ~p"/api/v1/browser/csrf_token")
    {conn, json_response(conn, 200)["csrf_token"]}
  end

  defp sign_in(conn, csrf, body, headers \\ []) do
    conn
    |> next_request()
    |> json_conn([{"x-csrf-token", csrf} | headers])
    |> post(~p"/api/v1/browser/session", Jason.encode!(body))
  end

  defp signed_in(conn, user, extra \\ %{}) do
    {conn, csrf} = anonymous(conn)
    conn = sign_in(conn, csrf, Map.merge(%{email: user.email, password: valid_password()}, extra))
    {conn, json_response(conn, 200)["csrf_token"]}
  end

  describe "get_browser_csrf_token" do
    test "a first-visit browser gets 200, a token and an anonymous session cookie", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/browser/csrf_token")

      body = assert_conforms(conn, "get_browser_csrf_token")
      assert conn.status == 200
      assert is_binary(body["csrf_token"])
      assert %{"_awrad_session" => %{http_only: true, same_site: "Lax"}} = conn.resp_cookies
    end

    test "a signed-in browser gets its session's token", %{conn: conn} do
      {conn, _csrf} = signed_in(conn, user_fixture())
      conn = conn |> next_request() |> get(~p"/api/v1/browser/csrf_token")

      assert assert_conforms(conn, "get_browser_csrf_token")["csrf_token"]
    end
  end

  describe "create_browser_session" do
    test "200 with the account and a new CSRF token; the session is renewed", %{conn: conn} do
      user = user_fixture()
      {anon, csrf} = anonymous(conn)
      conn = sign_in(anon, csrf, %{email: user.email, password: valid_password()})

      body = assert_conforms(conn, "create_browser_session")
      assert conn.status == 200
      assert body["account"]["id"] == user.id
      assert body["csrf_token"] != csrf

      assert conn.resp_cookies["_awrad_session"].value !=
               anon.resp_cookies["_awrad_session"].value

      # Remember-me defaults to true.
      assert %{max_age: 1_209_600, http_only: true} =
               conn.resp_cookies[UserAuth.remember_me_cookie()]

      me = conn |> next_request() |> get(~p"/api/v1/account")
      assert assert_conforms(me, "get_current_account")["id"] == user.id
    end

    test "the old CSRF token stops working after sign-in", %{conn: conn} do
      user = user_fixture()
      {anon, old_csrf} = anonymous(conn)
      conn = sign_in(anon, old_csrf, %{email: user.email, password: valid_password()})

      conn =
        conn
        |> next_request()
        |> put_req_header("x-csrf-token", old_csrf)
        |> delete(~p"/api/v1/browser/session")

      assert assert_conforms(conn, "delete_browser_session")["code"] == "csrf_token_invalid"
    end

    test "remember_me false sets no remember-me cookie", %{conn: conn} do
      {conn, _csrf} = signed_in(conn, user_fixture(), %{remember_me: false})
      refute Map.has_key?(conn.resp_cookies, UserAuth.remember_me_cookie())
    end

    test "403 csrf_token_invalid without the token", %{conn: conn} do
      user = user_fixture()
      {anon, _csrf} = anonymous(conn)
      conn = sign_in(anon, "wrong-token", %{email: user.email, password: valid_password()})

      assert assert_conforms(conn, "create_browser_session")["code"] == "csrf_token_invalid"
      assert conn.status == 403
    end

    test "401 invalid_credentials", %{conn: conn} do
      user = user_fixture()
      {anon, csrf} = anonymous(conn)
      conn = sign_in(anon, csrf, %{email: user.email, password: "the wrong passphrase"})

      assert assert_conforms(conn, "create_browser_session")["code"] == "invalid_credentials"
    end

    test "403 email_verification_required with a fresh code emailed", %{conn: conn} do
      user = unconfirmed_user_fixture()
      {anon, csrf} = anonymous(conn)
      conn = sign_in(anon, csrf, %{email: user.email, password: valid_password()})

      assert assert_conforms(conn, "create_browser_session")["code"] ==
               "email_verification_required"

      assert code_from_email(user.email)
    end

    test "422 validation_failed and 400 malformed_request", %{conn: conn} do
      {anon, csrf} = anonymous(conn)

      invalid = sign_in(anon, csrf, %{email: "nope", password: "x"})
      assert assert_conforms(invalid, "create_browser_session")["code"] == "validation_failed"

      malformed =
        sign_in(anon, csrf, %{email: "a@example.com", password: "x", remember_me: "yes"})

      assert assert_conforms(malformed, "create_browser_session")["code"] == "malformed_request"
    end

    test "429 after 10 sign-ins for one account", %{conn: conn} do
      user = user_fixture()
      {anon, csrf} = anonymous(conn)

      for _ <- 1..10,
          do: sign_in(anon, csrf, %{email: user.email, password: "the wrong passphrase"})

      conn = sign_in(anon, csrf, %{email: user.email, password: valid_password()})
      assert assert_conforms(conn, "create_browser_session")["code"] == "rate_limited"
    end

    test "a repeated Idempotency-Key signs in again; another body is idempotency_key_reused", %{
      conn: conn
    } do
      user = user_fixture()
      key = Awrad.UUIDv7.generate()
      {anon, csrf} = anonymous(conn)
      body = %{email: user.email, password: valid_password()}

      first = sign_in(anon, csrf, body, [{"idempotency-key", key}])
      repeat = sign_in(anon, csrf, body, [{"idempotency-key", key}])

      assert first.status == 200
      assert assert_conforms(repeat, "create_browser_session")["account"]["id"] == user.id
      assert repeat.resp_cookies["_awrad_session"]

      other =
        sign_in(anon, csrf, %{body | password: "another passphrase"}, [{"idempotency-key", key}])

      assert assert_conforms(other, "create_browser_session")["code"] == "idempotency_key_reused"
    end
  end

  describe "delete_browser_session" do
    test "204, the token and remember-me cookie are gone", %{conn: conn} do
      user = user_fixture()
      {conn, csrf} = signed_in(conn, user)

      out =
        conn
        |> next_request()
        |> put_req_header("x-csrf-token", csrf)
        |> delete(~p"/api/v1/browser/session")

      assert assert_conforms(out, "delete_browser_session") == nil
      assert out.status == 204
      assert out.resp_cookies[UserAuth.remember_me_cookie()].max_age == 0
      assert Repo.all(UserToken) == []
      assert out |> next_request() |> get(~p"/api/v1/account") |> Map.fetch!(:status) == 401
    end

    test "401 unauthenticated for an anonymous session", %{conn: conn} do
      {anon, csrf} = anonymous(conn)

      conn =
        anon
        |> next_request()
        |> put_req_header("x-csrf-token", csrf)
        |> delete(~p"/api/v1/browser/session")

      assert assert_conforms(conn, "delete_browser_session")["code"] == "unauthenticated"
    end

    test "403 csrf_token_invalid without the token", %{conn: conn} do
      {conn, _csrf} = signed_in(conn, user_fixture())
      conn = conn |> next_request() |> delete(~p"/api/v1/browser/session")

      assert assert_conforms(conn, "delete_browser_session")["code"] == "csrf_token_invalid"
      assert Repo.aggregate(UserToken, :count) == 1
    end
  end
end
