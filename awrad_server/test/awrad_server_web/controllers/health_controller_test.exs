defmodule AwradServerWeb.HealthControllerTest do
  use AwradServerWeb.ConnCase, async: true

  test "GET /up reports ok without authentication", %{conn: conn} do
    conn = get(conn, ~p"/up")

    assert json_response(conn, 200) == %{"status" => "ok"}
    assert get_resp_header(conn, "cache-control") == ["no-store"]
  end
end
