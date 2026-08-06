defmodule AwradApiWeb.HealthController do
  use AwradApiWeb, :controller

  @doc """
  Liveness probe for the container orchestrator and reverse proxy. Deliberately
  does not touch the database so a transient Postgres blip cannot cause the
  proxy to pull a healthy node out of rotation.
  """
  def show(conn, _params) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> json(%{status: "ok"})
  end
end
