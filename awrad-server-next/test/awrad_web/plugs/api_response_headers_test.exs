defmodule AwradWeb.Plugs.ApiResponseHeadersTest do
  use AwradWeb.ConnCase, async: true

  test "an unknown route is a problem+json 404 with the standard headers", %{conn: conn} do
    conn = get(conn, "/api/v1/does_not_exist")

    assert conn.status == 404
    assert [content_type] = get_resp_header(conn, "content-type")
    assert content_type =~ "application/problem+json"
    assert get_resp_header(conn, "cache-control") == ["no-store"]
    assert [_request_id] = get_resp_header(conn, "x-request-id")

    assert %{"code" => "not_found", "status" => 404, "type" => "urn:awrad:problem:not_found"} =
             Jason.decode!(conn.resp_body)
  end
end
