defmodule AwradWeb.Plugs.AccountAuth do
  @moduledoc """
  For operations that accept either credential (`get_current_account` and the
  account settings): a request with an `Authorization` header is checked
  **only** as a bearer token, and one without it **only** as a cookie session.
  A bad bearer token never falls back to the cookie, and the cookie branch
  never reads the header (ADR-2026-10-15). Either way, no account means
  `401 unauthenticated`.

  The cookie branch checks the CSRF token of state-changing requests first
  (`X-CSRF-Token`, `403 csrf_token_invalid`), like the browser pipeline. The
  bearer branch needs none: a bearer token isn't sent by the browser on its
  own.
  """

  @behaviour Plug

  import Plug.Conn

  alias AwradWeb.Plugs.{BearerAuth, BrowserSession}
  alias AwradWeb.UserAuth

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    if BearerAuth.authorization?(conn) do
      conn
      |> BearerAuth.fetch_bearer_scope()
      |> BearerAuth.require_bearer([])
    else
      conn = conn |> fetch_session() |> BrowserSession.check_csrf_token([])

      if conn.halted do
        conn
      else
        conn
        |> UserAuth.fetch_current_scope_for_user([])
        |> UserAuth.require_authenticated_user([])
      end
    end
  end
end
