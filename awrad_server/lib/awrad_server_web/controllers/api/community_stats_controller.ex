defmodule AwradServerWeb.Api.CommunityStatsController do
  use AwradServerWeb, :controller

  alias AwradServer.Community

  def show(conn, _params) do
    conn
    |> put_resp_header("cache-control", "public, max-age=300, stale-while-revalidate=600")
    |> json(Community.stats())
  end
end
