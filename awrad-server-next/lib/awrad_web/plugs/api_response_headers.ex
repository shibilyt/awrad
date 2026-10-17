defmodule AwradWeb.Plugs.ApiResponseHeaders do
  @moduledoc """
  Response headers every API response carries (`contracts/api/STYLE.md` §7, §12):

    * `Cache-Control: no-store` unless the action set its own caching;
    * `application/problem+json` for every error response, including the
      ones Phoenix renders for unmatched routes and crashes.

  `x-request-id` comes from `Plug.RequestId` in the endpoint.
  """

  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts), do: register_before_send(conn, &before_send/1)

  defp before_send(conn) do
    conn
    |> default_cache_control()
    |> problem_content_type()
  end

  defp default_cache_control(conn) do
    case get_resp_header(conn, "cache-control") do
      # Plug's default is "max-age=0, private, must-revalidate"; replace it.
      ["max-age=0, private, must-revalidate"] ->
        put_resp_header(conn, "cache-control", "no-store")

      [] ->
        put_resp_header(conn, "cache-control", "no-store")

      _explicit ->
        conn
    end
  end

  defp problem_content_type(%{status: status} = conn) when is_integer(status) and status >= 400 do
    case get_resp_header(conn, "content-type") do
      ["application/json" <> _] -> put_resp_content_type(conn, "application/problem+json")
      _other -> conn
    end
  end

  defp problem_content_type(conn), do: conn
end
