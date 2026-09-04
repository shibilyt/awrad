defmodule AwradServerWeb.EmailVerificationControllerTest do
  use AwradServerWeb.ConnCase, async: true

  import AwradServer.AccountsFixtures

  alias AwradServer.Accounts

  test "mobile landing does not consume the token and offers app and browser fallbacks", %{
    conn: conn
  } do
    {:ok, user} =
      Accounts.register_password_user(%{
        email: unique_user_email(),
        password: "A secure passphrase 42"
      })

    token =
      extract_user_token(fn url -> Accounts.deliver_user_verification_instructions(user, url) end)

    landing = get(conn, ~p"/auth/mobile/verify-email/#{token}")
    body = html_response(landing, 200)

    assert body =~ "awrad://verify-email?token="
    assert body =~ ~p"/auth/verify-email/#{token}"
    assert get_resp_header(landing, "cache-control") == ["no-store"]
    assert get_resp_header(landing, "referrer-policy") == ["no-referrer"]
    assert [csp] = get_resp_header(landing, "content-security-policy")
    assert csp =~ "default-src 'none'"

    verified =
      post(build_conn(), ~p"/api/auth/verify-email", %{
        token: token,
        device: %{installation_id: Ecto.UUID.generate()}
      })

    assert json_response(verified, 200)["user"]["email_verified"]
  end

  test "legacy browser route still consumes the token", %{conn: conn} do
    {:ok, user} =
      Accounts.register_password_user(%{
        email: unique_user_email(),
        password: "A secure passphrase 42"
      })

    token =
      extract_user_token(fn url -> Accounts.deliver_user_verification_instructions(user, url) end)

    assert get(conn, ~p"/auth/verify-email/#{token}") |> response(200) =~ "Email verified"
    assert get(build_conn(), ~p"/auth/verify-email/#{token}") |> response(422) =~ "invalid"
  end

  test "association metadata publishes both verification paths", %{conn: conn} do
    apple = get(conn, "/.well-known/apple-app-site-association")
    apple_body = json_response(apple, 200)
    [details] = apple_body["applinks"]["details"]

    assert details["appID"] == "TESTTEAMID.app.awrad.awrad"
    assert details["paths"] == ["/auth/mobile/verify-email/*", "/auth/verify-email/*"]
    assert get_resp_header(apple, "content-type") == ["application/json; charset=utf-8"]

    android = get(build_conn(), "/.well-known/assetlinks.json")
    [statement] = json_response(android, 200)

    assert statement["target"]["package_name"] == "app.awrad.awrad_dhikrgoalstracker"
    assert length(statement["target"]["sha256_cert_fingerprints"]) == 1
    assert get_resp_header(android, "content-type") == ["application/json; charset=utf-8"]
  end
end
