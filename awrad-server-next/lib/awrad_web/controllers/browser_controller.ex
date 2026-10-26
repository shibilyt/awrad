defmodule AwradWeb.BrowserController do
  @moduledoc """
  Endpoints only cookie-session (browser) clients use
  (`contracts/api/paths/browser.yaml`, ADR-2026-10-15). The `:browser_session`
  pipeline has already checked the CSRF token of state-changing requests and
  looked up the cookie session; it never reads an `Authorization` header.
  """

  use AwradWeb, :controller

  alias Awrad.Accounts
  alias AwradWeb.{AccountJSON, Locale, Params, RateLimit, UserAuth}

  action_fallback AwradWeb.FallbackController

  @doc """
  `get_browser_csrf_token`: the session's CSRF token, for any browser. A
  first-visit, signed-out browser gets an anonymous session cookie holding the
  token here, which `create_browser_session` needs. Never `401`.
  """
  @spec csrf_token(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def csrf_token(conn, _params) do
    json(conn, %{csrf_token: get_csrf_token()})
  end

  @doc """
  `create_browser_session`: signs in, renewing the session (a new session ID
  and CSRF token), and answers the account and the new token.
  """
  @spec create_session(Plug.Conn.t(), map()) :: Plug.Conn.t() | {:error, term()}
  def create_session(conn, _params) do
    with {:ok, params} <-
           Params.cast(conn,
             email: {:string, :required},
             password: {:string, :required},
             remember_me: {:boolean, :optional}
           ),
         %{email: email, password: password} = params,
         :ok <- RateLimit.check(conn, :sign_in, email),
         {:ok, user} <- Accounts.authenticate(email, password, Locale.from_conn(conn)) do
      conn = UserAuth.log_in_user(conn, user, Map.get(params, :remember_me, true))
      json(conn, %{account: AccountJSON.account(user), csrf_token: get_csrf_token()})
    end
  end

  @doc "`delete_browser_session`: signs out, deleting the session token and cookies."
  @spec delete_session(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete_session(conn, _params) do
    conn
    |> UserAuth.log_out_user()
    |> send_resp(:no_content, "")
  end
end
