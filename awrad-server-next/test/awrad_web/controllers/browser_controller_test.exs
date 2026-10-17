defmodule AwradWeb.BrowserControllerTest do
  use AwradWeb.ConnCase, async: true

  import AwradWeb.Contract

  describe "GET /api/v1/browser/csrf_token" do
    test "without a signed-in session it's 401 unauthenticated", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/browser/csrf_token")

      body = assert_conforms(conn, "get_browser_csrf_token")
      assert conn.status == 401
      assert body["code"] == "unauthenticated"
    end

    test "with a signed-in session it returns the session's token", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(user_token: "signed-in")
        |> get(~p"/api/v1/browser/csrf_token")

      body = assert_conforms(conn, "get_browser_csrf_token")
      assert conn.status == 200
      assert is_binary(body["csrf_token"])
    end
  end
end
