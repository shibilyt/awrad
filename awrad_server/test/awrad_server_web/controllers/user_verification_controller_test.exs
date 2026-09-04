defmodule AwradServerWeb.UserVerificationControllerTest do
  use AwradServerWeb.ConnCase, async: true

  import Ecto.Query
  import AwradServer.AccountsFixtures

  alias AwradServer.Accounts.UserToken
  alias AwradServer.Repo

  test "resends verification instructions for an authenticated unverified user", %{conn: conn} do
    user = unconfirmed_user_fixture()

    conn =
      conn
      |> log_in_user(user)
      |> post(~p"/users/resend-verification")

    assert redirected_to(conn) == ~p"/users/verification-required"

    assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
             "a new verification email is on its way"

    assert Repo.exists?(
             from token in UserToken,
               where: token.user_id == ^user.id and token.context == "verify_email"
           )
  end

  test "redirects verified users back to practice", %{conn: conn} do
    user = user_fixture()

    conn =
      conn
      |> log_in_user(user)
      |> post(~p"/users/resend-verification")

    assert redirected_to(conn) == ~p"/home"
  end
end
