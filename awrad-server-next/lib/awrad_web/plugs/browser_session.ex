defmodule AwradWeb.Plugs.BrowserSession do
  @moduledoc """
  The browser pipeline's CSRF check (ADR-2026-10-15, `contracts/api/STYLE.md` §11).

  `check_csrf_token/2` is Phoenix's CSRF protection for state-changing methods
  (the token in `X-CSRF-Token`), answering `403 csrf_token_invalid` instead of
  raising.

  The browser pipeline authenticates only from the session cookie
  (`AwradWeb.UserAuth`); it never reads an `Authorization` header, so a mobile
  bearer token doesn't sign a browser request in.
  """

  alias AwradWeb.Problem

  @doc "Checks the CSRF token like `Phoenix.Controller.protect_from_forgery/2`, as a problem response."
  @spec check_csrf_token(Plug.Conn.t(), term()) :: Plug.Conn.t()
  def check_csrf_token(conn, _opts) do
    Plug.CSRFProtection.call(conn, Plug.CSRFProtection.init([]))
  rescue
    Plug.CSRFProtection.InvalidCSRFTokenError -> Problem.send_code(conn, "csrf_token_invalid")
  end
end
