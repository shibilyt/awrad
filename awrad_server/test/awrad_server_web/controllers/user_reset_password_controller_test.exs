defmodule AwradServerWeb.UserResetPasswordControllerTest do
  use AwradServerWeb.ConnCase, async: true

  import AwradServer.AccountsFixtures

  setup do
    %{user: user_fixture()}
  end

  describe "POST /users/reset-password" do
    test "sends reset instructions for an existing account", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/reset-password", %{
          "user" => %{"email" => user.email}
        })

      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"
    end

    test "rate limits repeated reset requests for one account", %{conn: conn, user: user} do
      for _ <- 1..5 do
        request_conn =
          post(conn, ~p"/users/reset-password", %{
            "user" => %{"email" => user.email}
          })

        assert redirected_to(request_conn) == ~p"/users/log-in"
      end

      conn =
        post(conn, ~p"/users/reset-password", %{
          "user" => %{"email" => user.email}
        })

      assert response(conn, 429) == "Too many requests. Please try again later."
      assert get_resp_header(conn, "retry-after") != []
    end
  end
end
