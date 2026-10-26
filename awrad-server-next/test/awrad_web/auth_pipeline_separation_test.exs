defmodule AwradWeb.AuthPipelineSeparationTest do
  @moduledoc """
  ADR-2026-10-15: the bearer (mobile) and cookie (browser) pipelines resolve to
  the same accounts, and neither accepts the other's credential.
  """
  use AwradWeb.ConnCase, async: true

  import Awrad.AccountsFixtures
  import AwradWeb.Contract

  alias Awrad.Accounts
  alias AwradWeb.Plugs.BearerAuth
  alias AwradWeb.UserAuth

  setup do
    user = user_fixture()

    %{
      user: user,
      grant: grant_fixture(user),
      session_token: Accounts.generate_user_session_token(user)
    }
  end

  defp with_cookie_session(conn, session_token) do
    conn
    |> Plug.Test.init_test_session(user_token: session_token)
  end

  defp bearer(conn, token), do: put_req_header(conn, "authorization", "Bearer " <> token)

  describe "the bearer plug" do
    test "authenticates a valid access token", %{conn: conn, user: user, grant: grant} do
      conn = conn |> bearer(grant.access_token) |> BearerAuth.fetch_bearer_scope()
      assert conn.assigns.current_scope.user.id == user.id
    end

    test "ignores a valid browser session cookie", %{conn: conn, session_token: token} do
      conn = conn |> with_cookie_session(token) |> BearerAuth.fetch_bearer_scope()
      assert conn.assigns.current_scope == nil
    end
  end

  describe "the cookie session plug" do
    test "authenticates a valid browser session", %{conn: conn, user: user, session_token: token} do
      conn = conn |> with_cookie_session(token) |> UserAuth.fetch_current_scope_for_user([])
      assert conn.assigns.current_scope.user.id == user.id
    end

    test "ignores a valid bearer token", %{conn: conn, grant: grant} do
      conn =
        conn
        |> bearer(grant.access_token)
        |> Plug.Test.init_test_session(%{})
        |> UserAuth.fetch_current_scope_for_user([])

      assert conn.assigns.current_scope == nil
    end
  end

  describe "get_current_account (either credential)" do
    test "200 with a bearer token", %{conn: conn, user: user, grant: grant} do
      conn = conn |> bearer(grant.access_token) |> get(~p"/api/v1/account")
      assert assert_conforms(conn, "get_current_account")["id"] == user.id
    end

    test "200 with a cookie session", %{conn: conn, user: user, session_token: token} do
      conn = conn |> with_cookie_session(token) |> get(~p"/api/v1/account")
      assert assert_conforms(conn, "get_current_account")["email"] == user.email
    end

    test "a bad bearer token never falls back to a valid cookie", %{
      conn: conn,
      session_token: token
    } do
      conn =
        conn |> with_cookie_session(token) |> bearer("not-a-token") |> get(~p"/api/v1/account")

      assert assert_conforms(conn, "get_current_account")["code"] == "unauthenticated"
      assert conn.status == 401
    end

    test "a cookie for a signed-out or unknown session is 401", %{conn: conn} do
      conn =
        conn |> with_cookie_session(:crypto.strong_rand_bytes(32)) |> get(~p"/api/v1/account")

      assert assert_conforms(conn, "get_current_account")["code"] == "unauthenticated"
    end

    test "no credential is 401", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/account")
      assert assert_conforms(conn, "get_current_account")["code"] == "unauthenticated"
    end

    test "a non-bearer Authorization scheme is 401", %{conn: conn, grant: grant} do
      conn =
        conn
        |> put_req_header("authorization", "Basic " <> grant.access_token)
        |> get(~p"/api/v1/account")

      assert assert_conforms(conn, "get_current_account")["code"] == "unauthenticated"
    end
  end

  describe "browser routes" do
    test "a valid bearer token doesn't authenticate a browser sign-out", %{
      conn: conn,
      grant: grant
    } do
      conn = get(conn, ~p"/api/v1/browser/csrf_token")
      csrf = json_response(conn, 200)["csrf_token"]

      conn =
        conn
        |> next_request()
        |> bearer(grant.access_token)
        |> put_req_header("x-csrf-token", csrf)
        |> delete(~p"/api/v1/browser/session")

      assert assert_conforms(conn, "delete_browser_session")["code"] == "unauthenticated"
      assert conn.status == 401
      # The device session is untouched.
      assert {:ok, _user, _session} = Accounts.identify_device_session(grant.access_token)
    end

    test "a bearer token doesn't make get_browser_csrf_token sign anyone in", %{
      conn: conn,
      grant: grant
    } do
      conn = conn |> bearer(grant.access_token) |> get(~p"/api/v1/browser/csrf_token")

      assert assert_conforms(conn, "get_browser_csrf_token")["csrf_token"]
      assert conn.assigns.current_scope == nil
    end
  end
end
