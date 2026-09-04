defmodule AwradServerWeb.Api.CommunityStatsControllerTest do
  use AwradServerWeb.ConnCase, async: true

  test "is public and sends the shared-cache policy", %{conn: conn} do
    conn = get(conn, ~p"/api/community/stats")

    assert response(conn, 200)

    assert get_resp_header(conn, "cache-control") == [
             "public, max-age=300, stale-while-revalidate=600"
           ]

    assert %{
             "as_of" => as_of,
             "count_semantics" => "current_canonical_net",
             "total_tracked_goals" => 0,
             "approximate_total_counts" => "0",
             "approximate_dhikr_hours" => approximate_dhikr_hours,
             "seconds_per_count" => 1,
             "daily_counts" => daily_counts
           } = json_response(conn, 200)

    assert approximate_dhikr_hours == 0.0
    assert {:ok, _, 0} = DateTime.from_iso8601(as_of)
    assert length(daily_counts) == 7

    assert List.last(daily_counts) == %{
             "date" => Date.to_iso8601(Date.utc_today()),
             "approximate_count" => "0"
           }
  end
end
