defmodule AwradWeb.Plugs.BearerAuth do
  @moduledoc """
  The mobile credential (ADR-2026-07-12): `Authorization: Bearer <access token>`.

  Assigns `:current_scope` (a `Scope` with the device session) for a valid
  token on a live session of a verified account, and `nil` otherwise. It reads
  only the `Authorization` header, never the session or cookies, so a browser
  cookie can't stand in for a bearer token. `require_bearer/2` answers
  `401 unauthenticated` when there's no scope.
  """

  @behaviour Plug

  import Plug.Conn

  alias Awrad.Accounts
  alias Awrad.Accounts.Scope
  alias AwradWeb.Problem

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts), do: fetch_bearer_scope(conn)

  @doc "Assigns `:current_scope` from the bearer token, or `nil`."
  @spec fetch_bearer_scope(Plug.Conn.t()) :: Plug.Conn.t()
  def fetch_bearer_scope(conn) do
    with {:ok, token} <- bearer_token(conn),
         {:ok, user, session} <- Accounts.identify_device_session(token) do
      assign(conn, :current_scope, Scope.for_device_session(user, session))
    else
      _none -> assign(conn, :current_scope, nil)
    end
  end

  @doc "Halts with `401 unauthenticated` unless a bearer token authenticated the request."
  @spec require_bearer(Plug.Conn.t(), term()) :: Plug.Conn.t()
  def require_bearer(conn, _opts) do
    case conn.assigns[:current_scope] do
      %Scope{device_session: %Accounts.DeviceSession{}} -> conn
      _other -> Problem.send_code(conn, "unauthenticated")
    end
  end

  @doc "Whether the request carries an `Authorization` header at all."
  @spec authorization?(Plug.Conn.t()) :: boolean()
  def authorization?(conn), do: get_req_header(conn, "authorization") != []

  defp bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      [header] -> parse(header)
      _none_or_many -> :error
    end
  end

  defp parse(header) do
    case String.split(header, " ", parts: 2) do
      [scheme, token] when token != "" ->
        if String.downcase(scheme) == "bearer", do: {:ok, String.trim(token)}, else: :error

      _malformed ->
        :error
    end
  end
end
