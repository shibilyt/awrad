defmodule AwradServerWeb.PublicUrlAuthFlowTest do
  use AwradServerWeb.ConnCase, async: false

  import AwradServer.AccountsFixtures
  import Swoosh.TestAssertions

  alias AwradServer.Accounts

  @password "A secure passphrase 42"

  test "browser registration emails use the web host", %{conn: conn} do
    email = unique_user_email()

    post(conn, ~p"/users/register", %{"user" => %{"email" => email}})

    assert_email_sent(fn email ->
      assert email.text_body =~ "https://example.com/users/log-in/"
      refute email.text_body =~ "https://api.example.com/"
      true
    end)
  end

  test "mobile registration emails use the API host", %{conn: conn} do
    email = unique_user_email()

    post(conn, ~p"/api/auth/register", %{email: email, password: @password})

    assert_email_sent(fn email ->
      assert email.text_body =~ "https://api.example.com/auth/mobile/verify-email/"
      refute email.text_body =~ "https://example.com/"
      true
    end)
  end

  test "mobile landing browser fallback uses the web host", %{conn: conn} do
    {:ok, user} =
      Accounts.register_password_user(%{
        email: unique_user_email(),
        password: @password
      })

    token =
      extract_user_token(fn url ->
        AwradServer.Accounts.deliver_user_verification_instructions(user, url)
      end)

    body = get(conn, ~p"/auth/mobile/verify-email/#{token}") |> html_response(200)

    assert body =~ "https://example.com/auth/verify-email/#{token}"
    refute body =~ "https://api.example.com/auth/verify-email/#{token}"
  end

  test "API password reset emails use the web host", %{conn: conn} do
    {:ok, user} =
      Accounts.register_password_user(%{
        email: unique_user_email(),
        password: @password
      })

    post(conn, ~p"/api/auth/forgot-password", %{email: user.email})

    assert_email_sent(fn email ->
      assert email.text_body =~ "https://example.com/users/reset-password/"
      refute email.text_body =~ "https://api.example.com/users/reset-password/"
      true
    end)
  end
end
