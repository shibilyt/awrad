defmodule AwradApiWeb.Plugs.ApiAuth do
  @moduledoc """
  Plug that authenticates API requests via Bearer JWT access tokens.

  Reads the `Authorization: Bearer <token>` header, verifies the JWT,
  and assigns `current_user` and `current_scope` to the conn.
  """

  import Plug.Conn

  alias AwradApi.Accounts.{Scope, Token, User}

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, token} <- extract_bearer_token(conn),
         {:ok, claims} <- Token.verify_access_token(token),
         %User{} = user <- AwradApi.Repo.get(User, claims["sub"]) do
      conn
      |> assign(:current_user, user)
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
