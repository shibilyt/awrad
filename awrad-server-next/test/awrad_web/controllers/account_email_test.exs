defmodule AwradWeb.AccountEmailTest do
  @moduledoc """
  request_email_change and confirm_email_change, against
  contracts/api/paths/account_settings.yaml (slice 2b).
  """
  use AwradWeb.ConnCase, async: true

  import Awrad.AccountsFixtures
  import AwradWeb.Contract

  alias Awrad.Accounts.{EmailCode, User}
  alias Awrad.Repo

  defp me(request), do: get(request, ~p"/api/v1/account")

  defp request_change(request, new_email, headers \\ []) do
    request
    |> json_conn(headers)
    |> post(
      ~p"/api/v1/account/request_email_change",
      Jason.encode!(%{current_password: valid_password(), new_email: new_email})
    )
  end

  defp confirm(request, code, headers \\ []) do
    request
    |> json_conn(headers)
    |> post(~p"/api/v1/account/confirm_email_change", Jason.encode!(%{code: code}))
  end

  defp content_headers(conn),
    do: for(name <- ["content-type", "cache-control"], do: get_resp_header(conn, name))

  setup do
    user = user_fixture()
    %{user: user, phone: grant_fixture(user), other_phone: grant_fixture(user)}
  end

  describe "request_email_change and confirm_email_change" do
    test "a code to the new address; confirming switches the email and keeps sessions", ctx do
      new_email = "New." <> unique_email()
      conn = ctx.conn |> bearer_request(ctx.phone) |> request_change(new_email)

      assert assert_conforms(conn, "request_email_change") == nil
      assert conn.status == 202
      code = code_from_email(new_email)
      refute_email()
      # Nothing changes before the code.
      assert Repo.get!(User, ctx.user.id).email == ctx.user.email

      conn = ctx.conn |> bearer_request(ctx.phone) |> confirm(code)

      body = assert_conforms(conn, "confirm_email_change")
      assert conn.status == 200

      assert body == %{
               "id" => ctx.user.id,
               "email" => new_email,
               "created_at" => body["created_at"]
             }

      assert Repo.get!(User, ctx.user.id).email == new_email

      notice = assert_code_email(ctx.user.email)
      assert notice.subject == "Your Awrad account email was changed"
      assert notice.text_body =~ new_email

      assert ctx.conn |> bearer_request(ctx.phone) |> me() |> Map.get(:status) == 200
      assert ctx.conn |> bearer_request(ctx.other_phone) |> me() |> Map.get(:status) == 200

      # The code is spent.
      conn = ctx.conn |> bearer_request(ctx.phone) |> confirm(code)
      assert assert_conforms(conn, "confirm_email_change")["code"] == "email_change_code_invalid"
    end

    test "from a browser, with its CSRF token", ctx do
      {browser, csrf} = sign_in_browser(ctx.conn, ctx.user)
      new_email = unique_email()

      conn = browser |> browser_request(csrf) |> request_change(new_email)
      assert assert_conforms(conn, "request_email_change") == nil

      conn = browser |> browser_request(csrf) |> confirm(code_from_email(new_email))
      assert assert_conforms(conn, "confirm_email_change")["email"] == new_email
    end

    test "an address with an account gets a notice, and the response is the same", ctx do
      taken = user_fixture()
      free = unique_email()

      free_conn = ctx.conn |> bearer_request(ctx.phone) |> request_change(free)
      _code = code_from_email(free)

      taken_conn =
        ctx.conn |> bearer_request(ctx.phone) |> request_change(String.upcase(taken.email))

      assert assert_conforms(taken_conn, "request_email_change") == nil

      assert {taken_conn.status, taken_conn.resp_body} ==
               {free_conn.status, free_conn.resp_body}

      assert content_headers(taken_conn) == content_headers(free_conn)

      notice = assert_code_email(String.upcase(taken.email))
      assert notice.subject == "Someone tried to use this address for another Awrad account"
      refute notice.text_body =~ ~r/\b\d{6}\b/
      refute_email()

      # The new request cancelled the earlier code, and nothing is pending.
      refute Repo.get_by(EmailCode, user_id: ctx.user.id, purpose: :change_email)
      assert Repo.get!(User, taken.id).email == taken.email
    end

    test "a new request cancels the previous code", ctx do
      first = unique_email()
      second = unique_email()
      ctx.conn |> bearer_request(ctx.phone) |> request_change(first)
      old_code = code_from_email(first)
      ctx.conn |> bearer_request(ctx.phone) |> request_change(second)
      new_code = code_from_email(second)

      if old_code != new_code do
        conn = ctx.conn |> bearer_request(ctx.phone) |> confirm(old_code)

        assert assert_conforms(conn, "confirm_email_change")["code"] ==
                 "email_change_code_invalid"
      end

      conn = ctx.conn |> bearer_request(ctx.phone) |> confirm(new_code)
      assert assert_conforms(conn, "confirm_email_change")["email"] == second
    end

    test "the code email is localized", ctx do
      new_email = unique_email()

      ctx.conn
      |> bearer_request(ctx.phone)
      |> request_change(new_email, [{"accept-language", "ar"}])

      assert assert_code_email(new_email).subject == "رمز تغيير البريد الإلكتروني في أوراد"
    end

    test "409 email_taken when the address got an account in the meantime", ctx do
      new_email = unique_email()
      ctx.conn |> bearer_request(ctx.phone) |> request_change(new_email)
      code = code_from_email(new_email)
      _squatter = user_fixture(%{email: new_email})

      conn = ctx.conn |> bearer_request(ctx.phone) |> confirm(code)

      assert assert_conforms(conn, "confirm_email_change")["code"] == "email_taken"
      assert conn.status == 409
      assert Repo.get!(User, ctx.user.id).email == ctx.user.email
      refute_email()
    end

    test "422 field codes on request: wrong password, invalid and unchanged email", ctx do
      conn =
        ctx.conn
        |> bearer_request(ctx.phone)
        |> json_conn()
        |> post(
          ~p"/api/v1/account/request_email_change",
          Jason.encode!(%{current_password: "wrong", new_email: "not an email"})
        )

      body = assert_conforms(conn, "request_email_change")

      assert Enum.map(body["errors"], &{&1["field"], &1["code"]}) == [
               {"/current_password", "current_password_incorrect"},
               {"/new_email", "email_invalid"}
             ]

      conn =
        ctx.conn
        |> bearer_request(ctx.phone)
        |> request_change(" " <> String.upcase(ctx.user.email))

      assert [%{"field" => "/new_email", "code" => "email_unchanged"}] =
               assert_conforms(conn, "request_email_change")["errors"]

      refute_email()
    end

    test "422 on confirm: a wrong code, then spent after 5 tries; a malformed code", ctx do
      new_email = unique_email()
      ctx.conn |> bearer_request(ctx.phone) |> request_change(new_email)
      code = code_from_email(new_email)
      wrong = if code == "000000", do: "111111", else: "000000"

      for _ <- 1..5 do
        conn = ctx.conn |> bearer_request(ctx.phone) |> confirm(wrong)

        assert assert_conforms(conn, "confirm_email_change")["code"] ==
                 "email_change_code_invalid"
      end

      conn = ctx.conn |> bearer_request(ctx.phone) |> confirm(code)
      assert assert_conforms(conn, "confirm_email_change")["code"] == "email_change_code_invalid"

      conn = ctx.conn |> bearer_request(ctx.phone) |> confirm("12345")

      assert [%{"field" => "/code", "code" => "code_invalid"}] =
               assert_conforms(conn, "confirm_email_change")["errors"]
    end

    test "a code is the account's own", ctx do
      new_email = unique_email()
      ctx.conn |> bearer_request(ctx.phone) |> request_change(new_email)
      code = code_from_email(new_email)

      stranger = grant_fixture(user_fixture())
      conn = ctx.conn |> bearer_request(stranger) |> confirm(code)
      assert assert_conforms(conn, "confirm_email_change")["code"] == "email_change_code_invalid"
    end

    test "400, 401 and 403", ctx do
      conn =
        ctx.conn
        |> bearer_request(ctx.phone)
        |> json_conn()
        |> post(~p"/api/v1/account/request_email_change", Jason.encode!(%{new_email: "a@b.co"}))

      assert assert_conforms(conn, "request_email_change")["code"] == "malformed_request"

      conn = ctx.conn |> bearer_request(ctx.phone) |> confirm(123_456)
      assert assert_conforms(conn, "confirm_email_change")["code"] == "malformed_request"

      assert assert_conforms(request_change(ctx.conn, unique_email()), "request_email_change")[
               "code"
             ] == "unauthenticated"

      assert assert_conforms(confirm(ctx.conn, "123456"), "confirm_email_change")["code"] ==
               "unauthenticated"

      {browser, _csrf} = sign_in_browser(build_conn(), ctx.user)
      conn = browser |> next_request() |> request_change(unique_email())
      assert assert_conforms(conn, "request_email_change")["code"] == "csrf_token_invalid"

      conn = browser |> next_request() |> confirm("123456")
      assert assert_conforms(conn, "confirm_email_change")["code"] == "csrf_token_invalid"
    end

    test "429 after 5 requests an hour", ctx do
      for _ <- 1..5 do
        assert (ctx.conn |> bearer_request(ctx.phone) |> request_change(unique_email())).status ==
                 202
      end

      conn = ctx.conn |> bearer_request(ctx.phone) |> request_change(unique_email())
      assert assert_conforms(conn, "request_email_change")["code"] == "rate_limited"
    end

    test "429 after 10 confirmations an hour", ctx do
      for _ <- 1..10, do: ctx.conn |> bearer_request(ctx.phone) |> confirm("000000")

      conn = ctx.conn |> bearer_request(ctx.phone) |> confirm("000000")
      assert assert_conforms(conn, "confirm_email_change")["code"] == "rate_limited"
    end
  end
end
