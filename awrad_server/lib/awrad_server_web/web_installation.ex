defmodule AwradServerWeb.WebInstallation do
  @moduledoc """
  Keeps the server-generated browser installation identity in the signed web
  session. The session cookie is host-only and HttpOnly, so JavaScript cannot
  forge or read the value used to resolve a sync actor.
  """

  import Plug.Conn

  @session_key :web_installation_id
  @uuid_v4 ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, @session_key) do
      installation_id when is_binary(installation_id) ->
        if valid_uuid_v4?(installation_id) do
          assign(conn, :web_installation_id, installation_id)
        else
          put_installation(conn)
        end

      _other ->
        put_installation(conn)
    end
  end

  defp put_installation(conn) do
    installation_id = Ecto.UUID.generate()

    conn
    |> put_session(@session_key, installation_id)
    |> assign(:web_installation_id, installation_id)
  end

  defp valid_uuid_v4?(value), do: Regex.match?(@uuid_v4, value)
end
