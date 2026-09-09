defmodule AwradServer.LocationSearchTest do
  use ExUnit.Case, async: true

  alias AwradServer.LocationSearch

  test "normalizes named search results into a compact city label" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.query_params["q"] == "Bengaluru"
      assert conn.query_params["limit"] == "5"

      Req.Test.json(conn, [
        %{
          "lat" => "12.9767936",
          "lon" => "77.5900820",
          "name" => "Bengaluru",
          "display_name" => "Bengaluru, Bangalore North, Bengaluru Urban, Karnataka, India",
          "address" => %{
            "city" => "Bengaluru",
            "state" => "Karnataka",
            "country" => "India"
          }
        }
      ])
    end)

    assert {:ok, [result]} =
             LocationSearch.search(" Bengaluru ",
               req_options: [plug: {Req.Test, __MODULE__}]
             )

    assert result == %{
             name: "Bengaluru",
             display_name: "Bengaluru, Karnataka, India",
             latitude: 12.9767936,
             longitude: 77.590082
           }
  end

  test "normalizes reverse geocoding into the same display label" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.query_params["lat"] == "12.9716"
      assert conn.query_params["lon"] == "77.5946"

      Req.Test.json(conn, %{
        "lat" => "12.9716",
        "lon" => "77.5946",
        "display_name" => "Bengaluru, Bangalore North, Karnataka, India",
        "address" => %{
          "city" => "Bengaluru",
          "state" => "Karnataka",
          "country" => "India"
        }
      })
    end)

    assert {:ok, result} =
             LocationSearch.reverse(12.9716, 77.5946, req_options: [plug: {Req.Test, __MODULE__}])

    assert result == %{
             name: "Bengaluru",
             display_name: "Bengaluru, Karnataka, India",
             latitude: 12.9716,
             longitude: 77.5946
           }
  end

  test "rejects blank and oversized queries before making a request" do
    assert {:error, :invalid_query} = LocationSearch.search("  ")
    assert {:error, :invalid_query} = LocationSearch.search(String.duplicate("x", 121))
  end
end
