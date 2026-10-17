defmodule AwradWeb.BrowserController do
  @moduledoc """
  Endpoints only cookie-session (browser) clients use. See `get_browser_csrf_token`
  in `contracts/api/paths/browser.yaml`.
  """

  use AwradWeb, :controller

  alias AwradWeb.Problem

  @doc """
  Returns the session's CSRF token. Only signed-in cookie sessions may have one
  (ADR-2026-10-15). Until the accounts slice adds sign-in, no session carries a
  user, so every caller gets `401 unauthenticated`.
  """
  @spec csrf_token(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def csrf_token(conn, _params) do
    if get_session(conn, :user_token) do
      json(conn, %{csrf_token: Plug.CSRFProtection.get_csrf_token()})
    else
      Problem.send_problem(
        conn,
        401,
        "unauthenticated",
        "Authentication required",
        "no signed-in browser session"
      )
    end
  end
end
