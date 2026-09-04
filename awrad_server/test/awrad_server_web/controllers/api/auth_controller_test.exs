defmodule AwradServerWeb.Api.AuthControllerTest do
  use AwradServerWeb.ConnCase, async: false

  import AwradServer.AccountsFixtures
  import Swoosh.TestAssertions

  alias AwradServer.Accounts
  alias AwradServer.Accounts.Token

  @password "A secure passphrase 42"
  @device %{
    "installation_id" => "66a855c8-047d-4ee7-937f-3f565c8420ec",
    "name" => "Test Pixel",
    "platform" => "android"
  }

  test "registration is atomic, generic, and does not issue tokens", %{conn: conn} do
    email = unique_user_email()

    conn = post(conn, ~p"/api/auth/register", %{email: email, password: @password})
    body = json_response(conn, 202)

    assert body["verification_required"]
    refute Map.has_key?(body, "access_token")

    assert_email_sent(fn email ->
      assert email.text_body =~ "/auth/mobile/verify-email/"
      refute email.text_body =~ "/auth/verify-email/"
      true
    end)

    duplicate = post(build_conn(), ~p"/api/auth/register", %{email: email, password: @password})
    assert json_response(duplicate, 202)["message"] == body["message"]
  end

  test "unverified users cannot log in and verification creates a device session", %{conn: conn} do
    {:ok, user} =
      Accounts.register_password_user(%{email: unique_user_email(), password: @password})

    denied =
      post(conn, ~p"/api/auth/login", %{email: user.email, password: @password, device: @device})

    assert json_response(denied, 403)["error_code"] == "email_verification_required"

    token =
      extract_user_token(fn url -> Accounts.deliver_user_verification_instructions(user, url) end)

    verified = post(build_conn(), ~p"/api/auth/verify-email", %{token: token, device: @device})
    body = json_response(verified, 200)

    assert body["user"]["email_verified"]
    assert body["session"]["device_name"] == "Test Pixel"
    assert is_binary(body["access_token"])
    assert is_binary(body["refresh_token"])

    reused = post(build_conn(), ~p"/api/auth/verify-email", %{token: token, device: @device})
    assert json_response(reused, 422)["error"] =~ "invalid"
  end

  test "verification resend stays generic and rate limited", %{conn: conn} do
    {:ok, user} =
      Accounts.register_password_user(%{email: unique_user_email(), password: @password})

    existing = post(conn, ~p"/api/auth/verify-email/resend", %{email: user.email})
    existing_body = json_response(existing, 202)

    unknown_email = unique_user_email()
    unknown = post(build_conn(), ~p"/api/auth/verify-email/resend", %{email: unknown_email})
    assert json_response(unknown, 202) == existing_body

    Enum.each(1..3, fn _ ->
      response = post(build_conn(), ~p"/api/auth/verify-email/resend", %{email: unknown_email})
      assert json_response(response, 202) == existing_body
    end)

    limited = post(build_conn(), ~p"/api/auth/verify-email/resend", %{email: unknown_email})
    assert json_response(limited, 429)["error_code"] == "rate_limited"
    assert get_resp_header(limited, "retry-after") != []
  end

  test "refresh is idempotent for one request id and revokes on replay", %{conn: conn} do
    user = user_fixture() |> set_password()
    {:ok, {_session, _access, refresh}} = Token.create_session(user, @device)
    request_id = Ecto.UUID.generate()

    first = post(conn, ~p"/api/auth/refresh", %{refresh_token: refresh, request_id: request_id})
    first_body = json_response(first, 200)

    retry =
      post(build_conn(), ~p"/api/auth/refresh", %{refresh_token: refresh, request_id: request_id})

    retry_body = json_response(retry, 200)
    assert retry_body["refresh_token"] == first_body["refresh_token"]

    replay =
      post(build_conn(), ~p"/api/auth/refresh", %{
        refresh_token: refresh,
        request_id: Ecto.UUID.generate()
      })

    assert json_response(replay, 401)["error_code"] == "refresh_reuse_detected"

    revoked =
      post(build_conn(), ~p"/api/auth/refresh", %{
        refresh_token: first_body["refresh_token"],
        request_id: Ecto.UUID.generate()
      })

    assert json_response(revoked, 401)["error"] =~ "invalid"
  end

  test "logging in again from the same installation replaces its revoked session", %{conn: conn} do
    user = user_fixture() |> set_password()

    first =
      post(conn, ~p"/api/auth/login", %{
        email: user.email,
        password: valid_user_password(),
        device: @device
      })

    first_session_id = json_response(first, 200)["session"]["id"]

    second =
      post(build_conn(), ~p"/api/auth/login", %{
        email: user.email,
        password: valid_user_password(),
        device: @device
      })

    second_session_id = json_response(second, 200)["session"]["id"]
    refute second_session_id == first_session_id

    assert %{revoked_at: revoked_at, revoke_reason: "replaced"} =
             AwradServer.Repo.get!(AwradServer.Accounts.AuthSession, first_session_id)

    assert revoked_at
  end

  test "a bearer token cannot revoke another user's session", %{conn: conn} do
    user_a = user_fixture()
    user_b = user_fixture()
    {:ok, {_session_a, access_a, _refresh_a}} = Token.create_session(user_a, @device)

    {:ok, {session_b, _access_b, _refresh_b}} =
      Token.create_session(user_b, Map.put(@device, "installation_id", Ecto.UUID.generate()))

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{access_a}")
      |> delete(~p"/api/auth/sessions/#{session_b.id}")

    assert json_response(conn, 404)["error"] == "session not found"
  end
end
