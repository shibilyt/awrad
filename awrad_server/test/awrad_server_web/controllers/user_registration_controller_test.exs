defmodule AwradServerWeb.UserRegistrationControllerTest do
  use AwradServerWeb.ConnCase, async: true

  import AwradServer.AccountsFixtures

  describe "GET /users/register" do
    test "renders registration page", %{conn: conn} do
      conn = get(conn, ~p"/users/register")
      response = html_response(conn, 200)
      assert response =~ "Register"
      assert response =~ ~p"/users/log-in"
      assert response =~ ~p"/users/register"
    end

    test "redirects if already logged in", %{conn: conn} do
      conn = conn |> log_in_user(user_fixture()) |> get(~p"/users/register")

      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "POST /users/register" do
    @tag :capture_log
    test "creates account but does not log in", %{conn: conn} do
      email = unique_user_email()

      conn =
        post(conn, ~p"/users/register", %{
          "user" => valid_user_attributes(email: email)
        })

      refute get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/users/log-in"

      assert conn.assigns.flash["info"] ==
               "If the address can be registered, instructions will arrive shortly."
    end

    @tag :capture_log
    test "returns the same generic redirect for an existing email", %{conn: conn} do
      user = user_fixture()

      conn =
        post(conn, ~p"/users/register", %{
          "user" => %{"email" => user.email}
        })

      assert redirected_to(conn) == ~p"/users/log-in"

      assert conn.assigns.flash["info"] ==
               "If the address can be registered, instructions will arrive shortly."
    end

    @tag :capture_log
    test "rate limits repeated registrations from one IP", %{conn: conn} do
      for _ <- 1..5 do
        request_conn =
          post(conn, ~p"/users/register", %{
            "user" => valid_user_attributes()
          })

        assert redirected_to(request_conn) == ~p"/users/log-in"
      end

      conn =
        post(conn, ~p"/users/register", %{
          "user" => valid_user_attributes()
        })

      assert response(conn, 429) == "Too many requests. Please try again later."
      assert get_resp_header(conn, "retry-after") != []
    end

    test "render errors for invalid data", %{conn: conn} do
      conn =
        post(conn, ~p"/users/register", %{
          "user" => %{"email" => "with spaces"}
        })

      response = html_response(conn, 200)
      assert response =~ "Register"
      assert response =~ "must have the @ sign and no spaces"
    end
  end
end
