defmodule AwradServerWeb.Plugs.ApiAuth do
  @moduledoc """
  Plug that authenticates API requests via Bearer JWT access tokens.

  Reads the `Authorization: Bearer <token>` header, verifies the JWT,
  and assigns `current_user` and `current_scope` to the conn.
  """

  import Plug.Conn

  alias AwradServer.Accounts.{Scope, Token}

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, token} <- extract_bearer_token(conn),
         {:ok, claims} <- Token.verify_access_token(token),
         {:ok, user, session} <- Token.fetch_active_identity(claims) do
      conn
      |> assign(:current_user, user)
      |> assign(:current_session, session)
      |> assign(:current_scope, Scope.for_user(user))
    else
      _ -> unauthorized(conn)
    end
  end

  defp extract_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _ -> :error
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{error: "unauthorized"}))
    |> halt()
  end
end
