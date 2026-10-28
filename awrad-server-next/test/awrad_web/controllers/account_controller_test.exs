defmodule AwradWeb.AccountControllerTest do
  @moduledoc "register, verify, resend, request reset and reset, against contracts/api/paths/accounts.yaml."
  use AwradWeb.ConnCase, async: true

  import Awrad.AccountsFixtures
  import AwradWeb.Contract

  alias Awrad.Accounts.{DeviceSession, User, UserToken}
  alias Awrad.Repo

  defp post_json(conn, path, body, headers \\ []) do
    conn |> json_conn(headers) |> post(path, Jason.encode!(body))
  end

  describe "register_account" do
    test "202 and a verification code by email; the account isn't verified yet", %{conn: conn} do
      email = unique_email()
      conn = post_json(conn, ~p"/api/v1/accounts", %{email: email, password: valid_password()})

      assert assert_conforms(conn, "register_account") == nil
      assert conn.status == 202
      assert code_from_email(email) =~ ~r/\A\d{6}\z/
      assert %User{confirmed_at: nil} = Repo.get_by!(User, email: email)
    end

    test "trims the email and keeps its case", %{conn: conn} do
      post_json(conn, ~p"/api/v1/accounts", %{
        email: "  Amina.R@Example.com ",
        password: valid_password()
      })

      assert Repo.get_by!(User, email: "amina.r@example.com").email == "Amina.R@Example.com"
    end

    test "the email is localized from Accept-Language", %{conn: conn} do
      email = unique_email()

      post_json(conn, ~p"/api/v1/accounts", %{email: email, password: valid_password()}, [
        {"accept-language", "ar-SA, en;q=0.5"}
      ])

      assert assert_code_email(email).subject =~ "أوراد"
    end

    test "doesn't reveal an existing email: same status, same body, no email to a verified account",
         %{conn: conn} do
      verified = user_fixture()
      body = %{email: unique_email(), password: valid_password()}

      new = post_json(conn, ~p"/api/v1/accounts", body)
      _ = code_from_email(body.email)
      existing = post_json(fresh(conn), ~p"/api/v1/accounts", %{body | email: verified.email})

      assert assert_conforms(existing, "register_account") == nil
      assert {existing.status, existing.resp_body} == {new.status, new.resp_body}
      assert content_headers(existing) == content_headers(new)
      refute_email()
      # The verified account's password is untouched.
      assert User.valid_password?(Repo.get!(User, verified.id), valid_password())
    end

    test "an unverified email gets a new code, and the latest password wins", %{conn: conn} do
      user = unconfirmed_user_fixture()
      new_password = "the inbox owner's real passphrase"

      conn = post_json(conn, ~p"/api/v1/accounts", %{email: user.email, password: new_password})

      assert conn.status == 202
      assert code_from_email(user.email)
      assert User.valid_password?(Repo.get!(User, user.id), new_password)
    end

    test "422 validation_failed with every field code", %{conn: conn} do
      conn = post_json(conn, ~p"/api/v1/accounts", %{email: "amina@localhost", password: "short"})

      body = assert_conforms(conn, "register_account")
      assert conn.status == 422
      assert body["code"] == "validation_failed"

      assert Enum.map(body["errors"], &{&1["field"], &1["code"]}) == [
               {"/email", "email_invalid"},
               {"/password", "password_too_short"}
             ]

      refute_email()
    end

    for {password, code} <- [
          {String.duplicate("a", 129), "password_too_long"},
          {"password1234", "password_too_common"}
        ] do
      @password password
      @code code
      test "422 #{code}", %{conn: conn} do
        conn =
          post_json(conn, ~p"/api/v1/accounts", %{email: unique_email(), password: @password})

        body = assert_conforms(conn, "register_account")
        assert [%{"field" => "/password", "code" => @code}] = body["errors"]
      end
    end

    test "400 for an unknown field, a missing field, a wrong type or a non-JSON body", %{
      conn: conn
    } do
      for body <- [
            %{email: unique_email(), password: valid_password(), passwrd: "x"},
            %{email: unique_email()},
            %{email: unique_email(), password: 123_456_789_012},
            [1, 2]
          ] do
        conn = post_json(conn, ~p"/api/v1/accounts", body)
        assert assert_conforms(conn, "register_account")["code"] == "malformed_request"
      end

      conn =
        conn
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> post("/api/v1/accounts", "email=a")

      assert assert_conforms(conn, "register_account")["code"] == "malformed_request"
    end

    test "429 with Retry-After after 5 an hour for one email", %{conn: conn} do
      email = unique_email()

      for _ <- 1..5 do
        assert post_json(fresh(conn), ~p"/api/v1/accounts", %{
                 email: email,
                 password: valid_password()
               }).status == 202
      end

      conn =
        post_json(fresh(conn), ~p"/api/v1/accounts", %{
          email: String.upcase(email),
          password: valid_password()
        })

      body = assert_conforms(conn, "register_account")
      assert conn.status == 429
      assert body["code"] == "rate_limited"
      assert [retry_after] = get_resp_header(conn, "retry-after")
      assert String.to_integer(retry_after) in 1..3600
    end
  end

  describe "verify_account_email" do
    setup %{conn: conn} do
      email = unique_email()
      post_json(conn, ~p"/api/v1/accounts", %{email: email, password: valid_password()})
      %{email: email, code: code_from_email(email)}
    end

    test "204 and the account is verified", %{conn: conn, email: email, code: code} do
      conn =
        post_json(fresh(conn), ~p"/api/v1/accounts/verify_email", %{email: email, code: code})

      assert assert_conforms(conn, "verify_account_email") == nil
      assert conn.status == 204
      assert Repo.get_by!(User, email: email).confirmed_at
    end

    test "422 verification_code_invalid for a wrong code or an unknown email", %{
      conn: conn,
      email: email,
      code: code
    } do
      wrong = if code == "000000", do: "111111", else: "000000"

      for body <- [%{email: email, code: wrong}, %{email: unique_email(), code: code}] do
        conn = post_json(fresh(conn), ~p"/api/v1/accounts/verify_email", body)

        assert assert_conforms(conn, "verify_account_email")["code"] ==
                 "verification_code_invalid"
      end

      refute Repo.get_by!(User, email: email).confirmed_at
    end

    test "422 validation_failed for a code that isn't six ASCII digits", %{
      conn: conn,
      email: email
    } do
      # The server doesn't normalise other digit scripts (account-model email_code_input is client-only).
      conn = post_json(conn, ~p"/api/v1/accounts/verify_email", %{email: email, code: "٤٨٢٩١٣"})

      body = assert_conforms(conn, "verify_account_email")
      assert body["code"] == "validation_failed"
      assert [%{"field" => "/code", "code" => "code_invalid"}] = body["errors"]
    end

    test "after 5 wrong tries even the right code fails", %{conn: conn, email: email, code: code} do
      wrong = if code == "000000", do: "111111", else: "000000"

      for _ <- 1..5,
          do:
            post_json(fresh(conn), ~p"/api/v1/accounts/verify_email", %{email: email, code: wrong})

      conn =
        post_json(fresh(conn), ~p"/api/v1/accounts/verify_email", %{email: email, code: code})

      assert assert_conforms(conn, "verify_account_email")["code"] == "verification_code_invalid"
    end

    test "verifying doesn't sign in", %{conn: conn, email: email, code: code} do
      conn = post_json(conn, ~p"/api/v1/accounts/verify_email", %{email: email, code: code})

      assert conn.resp_cookies == %{}
      assert Repo.all(UserToken) == []
    end
  end

  describe "resend_verification_code" do
    test "202, and a new code replaces the old one", %{conn: conn} do
      email = unique_email()
      post_json(conn, ~p"/api/v1/accounts", %{email: email, password: valid_password()})
      old = code_from_email(email)

      conn =
        post_json(fresh(conn), ~p"/api/v1/accounts/resend_verification_code", %{email: email})

      assert assert_conforms(conn, "resend_verification_code") == nil
      assert conn.status == 202
      new = code_from_email(email)

      if old != new do
        conn =
          post_json(fresh(conn), ~p"/api/v1/accounts/verify_email", %{email: email, code: old})

        assert conn.status == 422
      end

      assert post_json(fresh(conn), ~p"/api/v1/accounts/verify_email", %{email: email, code: new}).status ==
               204
    end

    test "the same 202 for unknown and verified emails, with no email", %{conn: conn} do
      unknown =
        post_json(conn, ~p"/api/v1/accounts/resend_verification_code", %{email: unique_email()})

      verified =
        post_json(fresh(conn), ~p"/api/v1/accounts/resend_verification_code", %{
          email: user_fixture().email
        })

      assert assert_conforms(unknown, "resend_verification_code") == nil
      assert {unknown.status, unknown.resp_body} == {verified.status, verified.resp_body}
      assert content_headers(unknown) == content_headers(verified)
      refute_email()
    end

    test "422 for an invalid email", %{conn: conn} do
      conn = post_json(conn, ~p"/api/v1/accounts/resend_verification_code", %{email: "nope"})
      assert assert_conforms(conn, "resend_verification_code")["code"] == "validation_failed"
    end
  end

  describe "request_password_reset and reset_password" do
    setup do
      user = user_fixture()
      %{user: user, grant: grant_fixture(user)}
    end

    test "the same 202 for known and unknown emails; only the known one gets a code", %{
      conn: conn,
      user: user
    } do
      known = post_json(conn, ~p"/api/v1/accounts/request_password_reset", %{email: user.email})

      unknown =
        post_json(fresh(conn), ~p"/api/v1/accounts/request_password_reset", %{
          email: unique_email()
        })

      assert assert_conforms(known, "request_password_reset") == nil
      assert {known.status, known.resp_body} == {unknown.status, unknown.resp_body}
      assert code_from_email(user.email)
      refute_email()
    end

    test "reset sets the password, verifies the email and revokes every session", %{conn: conn} do
      user = unconfirmed_user_fixture()
      grant = grant_fixture(user)
      browser_token = Awrad.Accounts.generate_user_session_token(user)

      post_json(conn, ~p"/api/v1/accounts/request_password_reset", %{email: user.email})
      code = code_from_email(user.email)
      new_password = "a brand new passphrase"

      conn =
        post_json(fresh(conn), ~p"/api/v1/accounts/reset_password", %{
          email: user.email,
          code: code,
          new_password: new_password
        })

      assert assert_conforms(conn, "reset_password") == nil
      assert conn.status == 204

      user = Repo.get!(User, user.id)
      assert user.confirmed_at
      assert User.valid_password?(user, new_password)
      refute User.valid_password?(user, valid_password())

      assert %DeviceSession{revoke_reason: "password_reset"} =
               Repo.get!(DeviceSession, grant.session.id)

      assert Awrad.Accounts.identify_device_session(grant.access_token) == :error

      assert Awrad.Accounts.refresh_device_session(grant.refresh_token, Awrad.UUIDv7.generate()) ==
               {:error, :refresh_token_invalid}

      assert Awrad.Accounts.get_user_by_session_token(browser_token) == nil
    end

    test "422 reset_code_invalid for a wrong code; the password is unchanged", %{
      conn: conn,
      user: user
    } do
      post_json(conn, ~p"/api/v1/accounts/request_password_reset", %{email: user.email})
      code = code_from_email(user.email)
      wrong = if code == "000000", do: "111111", else: "000000"

      conn =
        post_json(fresh(conn), ~p"/api/v1/accounts/reset_password", %{
          email: user.email,
          code: wrong,
          new_password: "a brand new passphrase"
        })

      assert assert_conforms(conn, "reset_password")["code"] == "reset_code_invalid"
      assert User.valid_password?(Repo.get!(User, user.id), valid_password())
    end

    test "422 validation_failed on /new_password, without spending a try", %{
      conn: conn,
      user: user
    } do
      post_json(conn, ~p"/api/v1/accounts/request_password_reset", %{email: user.email})
      code = code_from_email(user.email)

      conn =
        post_json(fresh(conn), ~p"/api/v1/accounts/reset_password", %{
          email: user.email,
          code: code,
          new_password: "short"
        })

      body = assert_conforms(conn, "reset_password")
      assert [%{"field" => "/new_password", "code" => "password_too_short"}] = body["errors"]
      assert Repo.get_by!(Awrad.Accounts.EmailCode, user_id: user.id).attempts == 0
    end
  end

  describe "Idempotency-Key" do
    test "a repeat with the same key and body replays the result without re-running it", %{
      conn: conn
    } do
      key = Awrad.UUIDv7.generate()
      body = %{email: unique_email(), password: valid_password()}

      first = post_json(conn, ~p"/api/v1/accounts", body, [{"idempotency-key", key}])
      _ = code_from_email(body.email)
      repeat = post_json(fresh(conn), ~p"/api/v1/accounts", body, [{"idempotency-key", key}])

      assert assert_conforms(repeat, "register_account") == nil
      assert repeat.status == first.status
      refute_email()
    end

    test "the same key with another body is 422 idempotency_key_reused", %{conn: conn} do
      key = Awrad.UUIDv7.generate()

      post_json(
        conn,
        ~p"/api/v1/accounts",
        %{email: unique_email(), password: valid_password()},
        [{"idempotency-key", key}]
      )

      conn =
        post_json(
          fresh(conn),
          ~p"/api/v1/accounts",
          %{email: unique_email(), password: valid_password()},
          [
            {"idempotency-key", key}
          ]
        )

      assert assert_conforms(conn, "register_account")["code"] == "idempotency_key_reused"
    end

    test "a malformed key is 400 (identity uuid_format)", %{conn: conn} do
      malformed = [
        "not-a-uuid",
        String.upcase(Awrad.UUIDv7.generate()),
        "00000000-0000-0000-0000-000000000000",
        "ffffffff-ffff-ffff-ffff-ffffffffffff"
      ]

      for key <- malformed do
        conn =
          post_json(
            %{build_conn() | remote_ip: conn.remote_ip},
            ~p"/api/v1/accounts",
            %{email: unique_email(), password: valid_password()},
            [{"idempotency-key", key}]
          )

        assert assert_conforms(conn, "register_account")["code"] == "malformed_request"
      end
    end
  end

  # The documented 400, 422 and 429 of the other public operations, with a valid
  # body for each and the per-account hourly limit.
  @public [
    {"verify_account_email", "/api/v1/accounts/verify_email", 10, %{"code" => "123456"}},
    {"resend_verification_code", "/api/v1/accounts/resend_verification_code", 5, %{}},
    {"request_password_reset", "/api/v1/accounts/request_password_reset", 5, %{}},
    {"reset_password", "/api/v1/accounts/reset_password", 10,
     %{"code" => "123456", "new_password" => "a brand new passphrase"}}
  ]

  for {operation, path, limit, extra} <- @public do
    @operation operation
    @path path
    @limit limit
    @extra extra

    describe "#{operation} errors" do
      test "400 malformed_request for an unknown field", %{conn: conn} do
        body = Map.merge(@extra, %{"email" => unique_email(), "emial" => "typo"})
        conn = post_json(conn, @path, body)

        assert assert_conforms(conn, @operation)["code"] == "malformed_request"
        assert conn.status == 400
      end

      test "422 validation_failed for an invalid email", %{conn: conn} do
        conn = post_json(conn, @path, Map.put(@extra, "email", "not an email"))

        body = assert_conforms(conn, @operation)
        assert body["code"] == "validation_failed"
        assert {"/email", "email_invalid"} in Enum.map(body["errors"], &{&1["field"], &1["code"]})
      end

      test "429 rate_limited after #{limit} an hour for one email", %{conn: conn} do
        body = Map.put(@extra, "email", unique_email())
        for _ <- 1..@limit, do: post_json(fresh(conn), @path, body)

        conn = post_json(fresh(conn), @path, body)
        assert assert_conforms(conn, @operation)["code"] == "rate_limited"
        assert [_seconds] = get_resp_header(conn, "retry-after")
      end
    end
  end

  # A new request from the same client (same IP), without cookies.
  defp fresh(conn), do: %{build_conn() | remote_ip: conn.remote_ip}

  defp content_headers(conn) do
    for {name, value} <- conn.resp_headers,
        name in ["content-type", "cache-control", "retry-after"],
        do: {name, value}
  end
end
