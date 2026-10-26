defmodule AwradWeb.AccountPasswordTest do
  @moduledoc """
  change_password and delete_account, against
  contracts/api/paths/account_settings.yaml (slice 2b), with both credentials.
  """
  use AwradWeb.ConnCase, async: true

  import Awrad.AccountsFixtures
  import AwradWeb.Contract
  import Ecto.Query

  alias Awrad.Accounts.{DeviceSession, EmailCode, RateLimiter, RefreshToken, User, UserToken}
  alias Awrad.Idempotency.Record
  alias Awrad.Repo
  alias AwradWeb.UserAuth

  @new_password "a brand new passphrase"

  defp me(request), do: get(request, ~p"/api/v1/account")
  defp status(conn), do: conn.status

  defp change_password(request, body, headers \\ []) do
    request
    |> json_conn(headers)
    |> post(~p"/api/v1/account/change_password", Jason.encode!(body))
  end

  defp delete_account(request, body, headers \\ []) do
    request |> json_conn(headers) |> post(~p"/api/v1/account/delete", Jason.encode!(body))
  end

  defp change(current \\ valid_password()),
    do: %{current_password: current, new_password: @new_password}

  setup %{conn: conn} do
    user = user_fixture()
    phone = grant_fixture(user)
    other_phone = grant_fixture(user)
    {browser, csrf} = sign_in_browser(conn, user)
    {other_browser, other_csrf} = sign_in_browser(build_conn(), user)

    %{
      user: user,
      phone: phone,
      other_phone: other_phone,
      browser: browser,
      csrf: csrf,
      other_browser: other_browser,
      other_csrf: other_csrf
    }
  end

  describe "change_password" do
    test "from a device: 204, other sessions end, the caller stays, and a notice", ctx do
      conn = ctx.conn |> bearer_request(ctx.phone) |> change_password(change())

      assert assert_conforms(conn, "change_password") == nil
      assert conn.status == 204
      assert User.valid_password?(Repo.get!(User, ctx.user.id), @new_password)

      assert ctx.conn |> bearer_request(ctx.phone) |> me() |> status() == 200
      assert ctx.conn |> bearer_request(ctx.other_phone) |> me() |> status() == 401
      assert ctx.browser |> browser_request(ctx.csrf) |> me() |> status() == 401
      assert ctx.other_browser |> browser_request(ctx.other_csrf) |> me() |> status() == 401

      assert Repo.get!(DeviceSession, ctx.other_phone.session.id).revoke_reason ==
               "password_changed"

      assert assert_code_email(ctx.user.email).subject == "Your Awrad password was changed"
    end

    test "from a browser: the caller keeps its cookie and CSRF token", ctx do
      conn = ctx.browser |> browser_request(ctx.csrf) |> change_password(change())

      assert assert_conforms(conn, "change_password") == nil
      refute Map.has_key?(conn.resp_cookies, UserAuth.remember_me_cookie())

      assert ctx.browser |> browser_request(ctx.csrf) |> me() |> status() == 200
      assert ctx.other_browser |> browser_request(ctx.other_csrf) |> me() |> status() == 401
      assert ctx.conn |> bearer_request(ctx.phone) |> me() |> status() == 401

      # The same CSRF token still authorises a change.
      again =
        ctx.browser
        |> browser_request(ctx.csrf)
        |> change_password(%{current_password: @new_password, new_password: valid_password()})

      assert again.status == 204
    end

    test "the notice is localized", ctx do
      ctx.conn
      |> bearer_request(ctx.phone)
      |> change_password(change(), [{"accept-language", "ar"}])

      assert assert_code_email(ctx.user.email).subject =~ "أوراد"
    end

    test "422 for a wrong current password, with every field error; nothing changes", ctx do
      conn =
        ctx.conn
        |> bearer_request(ctx.phone)
        |> change_password(%{current_password: "not my password", new_password: "short"})

      body = assert_conforms(conn, "change_password")
      assert body["code"] == "validation_failed"

      assert Enum.map(body["errors"], &{&1["field"], &1["code"]}) == [
               {"/current_password", "current_password_incorrect"},
               {"/new_password", "password_too_short"}
             ]

      assert User.valid_password?(Repo.get!(User, ctx.user.id), valid_password())
      assert ctx.conn |> bearer_request(ctx.other_phone) |> me() |> status() == 200
      refute_email()
    end

    test "422 for a common new password or an empty current one", ctx do
      conn =
        ctx.conn
        |> bearer_request(ctx.phone)
        |> change_password(%{current_password: valid_password(), new_password: "password1234"})

      assert [%{"field" => "/new_password", "code" => "password_too_common"}] =
               assert_conforms(conn, "change_password")["errors"]

      conn = ctx.conn |> bearer_request(ctx.phone) |> change_password(change(""))

      assert [%{"field" => "/current_password", "code" => "current_password_incorrect"}] =
               assert_conforms(conn, "change_password")["errors"]
    end

    test "400 for a malformed body", ctx do
      for body <- [%{current_password: valid_password()}, Map.put(change(), :extra, 1)] do
        conn = ctx.conn |> bearer_request(ctx.phone) |> change_password(body)
        assert assert_conforms(conn, "change_password")["code"] == "malformed_request"
      end
    end

    test "401 without a credential; 403 for a cookie without its CSRF token", ctx do
      conn = change_password(ctx.conn, change())
      assert assert_conforms(conn, "change_password")["code"] == "unauthenticated"

      conn = ctx.browser |> next_request() |> change_password(change())
      assert assert_conforms(conn, "change_password")["code"] == "csrf_token_invalid"
      assert User.valid_password?(Repo.get!(User, ctx.user.id), valid_password())
    end

    test "429 with Retry-After after 10 password checks in 15 minutes", ctx do
      for _ <- 1..10 do
        assert ctx.conn
               |> bearer_request(ctx.phone)
               |> change_password(change("wrong"))
               |> status() ==
                 422
      end

      conn = ctx.conn |> bearer_request(ctx.phone) |> change_password(change())
      assert assert_conforms(conn, "change_password")["code"] == "rate_limited"
      assert [_seconds] = get_resp_header(conn, "retry-after")
    end

    test "a repeat with the same Idempotency-Key replays without running again", ctx do
      key = [{"idempotency-key", Ecto.UUID.generate()}]

      assert ctx.conn |> bearer_request(ctx.phone) |> change_password(change(), key) |> status() ==
               204

      assert_code_email(ctx.user.email)

      repeat = ctx.conn |> bearer_request(ctx.phone) |> change_password(change(), key)
      assert assert_conforms(repeat, "change_password") == nil
      refute_email()
    end
  end

  describe "delete_account" do
    test "from a device: 204, every row of the account goes, every credential is rejected", ctx do
      other = user_fixture()
      other_phone = grant_fixture(other)
      EmailCode.issue(ctx.user, :reset_password)
      :ok = RateLimiter.check(:password_check, nil, ctx.user.id)

      ctx.conn
      |> bearer_request(ctx.phone)
      |> json_conn([{"idempotency-key", Ecto.UUID.generate()}])
      |> post(~p"/api/v1/account/sessions/revoke_others")

      assert Repo.exists?(where(Record, user_id: ^ctx.user.id))

      conn =
        ctx.conn
        |> bearer_request(ctx.phone)
        |> delete_account(%{current_password: valid_password()}, [
          {"idempotency-key", Ecto.UUID.generate()},
          {"accept-language", "ml"}
        ])

      assert assert_conforms(conn, "delete_account") == nil
      assert conn.status == 204

      user_id = ctx.user.id
      session_ids = [ctx.phone.session.id, ctx.other_phone.session.id]

      for query <- [
            where(User, id: ^user_id),
            where(UserToken, user_id: ^user_id),
            where(EmailCode, user_id: ^user_id),
            where(DeviceSession, user_id: ^user_id),
            from(t in RefreshToken, where: t.device_session_id in ^session_ids),
            where(Record, user_id: ^user_id)
          ] do
        refute Repo.exists?(query), inspect(query)
      end

      assert :ok = RateLimiter.check(:password_check, nil, ctx.user.id)
      assert Repo.aggregate(where(RateLimiter, scope: "password_check:account"), :count) == 1

      assert ctx.conn |> bearer_request(ctx.phone) |> me() |> status() == 401
      assert ctx.browser |> browser_request(ctx.csrf) |> me() |> status() == 401
      assert ctx.conn |> bearer_request(other_phone) |> me() |> status() == 200

      email = assert_code_email(ctx.user.email)
      assert email.subject == "നിങ്ങളുടെ Awrad അക്കൗണ്ട് ഇല്ലാതാക്കി"
    end

    test "a repeat after success is 401: the credential ended with the account", ctx do
      key = [{"idempotency-key", Ecto.UUID.generate()}]
      body = %{current_password: valid_password()}
      assert ctx.conn |> bearer_request(ctx.phone) |> delete_account(body, key) |> status() == 204

      repeat = ctx.conn |> bearer_request(ctx.phone) |> delete_account(body, key)
      assert assert_conforms(repeat, "delete_account")["code"] == "unauthenticated"
    end

    test "from a browser: its cookies are cleared", ctx do
      conn =
        ctx.browser
        |> browser_request(ctx.csrf)
        |> delete_account(%{current_password: valid_password()})

      assert assert_conforms(conn, "delete_account") == nil
      assert %{max_age: 0} = conn.resp_cookies[UserAuth.remember_me_cookie()]
      assert conn |> next_request() |> me() |> status() == 401
      assert ctx.other_browser |> browser_request(ctx.other_csrf) |> me() |> status() == 401
      refute Repo.get(User, ctx.user.id)
    end

    test "422 for a wrong password; the account stays", ctx do
      conn = ctx.conn |> bearer_request(ctx.phone) |> delete_account(%{current_password: "nope"})

      assert [%{"field" => "/current_password", "code" => "current_password_incorrect"}] =
               assert_conforms(conn, "delete_account")["errors"]

      assert Repo.get(User, ctx.user.id)
      assert ctx.conn |> bearer_request(ctx.phone) |> me() |> status() == 200
      refute_email()
    end

    test "400 for a malformed body or Idempotency-Key", ctx do
      conn =
        ctx.conn |> bearer_request(ctx.phone) |> delete_account(%{password: valid_password()})

      assert assert_conforms(conn, "delete_account")["code"] == "malformed_request"

      conn =
        ctx.conn
        |> bearer_request(ctx.phone)
        |> delete_account(%{current_password: valid_password()}, [{"idempotency-key", "nope"}])

      assert assert_conforms(conn, "delete_account")["code"] == "malformed_request"
      assert Repo.get(User, ctx.user.id)
    end

    test "401 without a credential; 403 for a cookie without its CSRF token", ctx do
      conn = delete_account(ctx.conn, %{current_password: valid_password()})
      assert assert_conforms(conn, "delete_account")["code"] == "unauthenticated"

      conn =
        ctx.browser |> next_request() |> delete_account(%{current_password: valid_password()})

      assert assert_conforms(conn, "delete_account")["code"] == "csrf_token_invalid"
      assert Repo.get(User, ctx.user.id)
    end

    test "429 after 10 password checks in 15 minutes", ctx do
      for _ <- 1..10 do
        ctx.conn |> bearer_request(ctx.phone) |> delete_account(%{current_password: "wrong"})
      end

      conn =
        ctx.conn
        |> bearer_request(ctx.phone)
        |> delete_account(%{current_password: valid_password()})

      assert assert_conforms(conn, "delete_account")["code"] == "rate_limited"
      assert Repo.get(User, ctx.user.id)
    end
  end
end
