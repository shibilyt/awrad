defmodule AwradServerWeb.PracticeLocationSearchLiveTest do
  use AwradServerWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias AwradServer.PracticeSettings.DeviceContext
  alias AwradServer.Repo

  setup do
    previous = Application.get_env(:awrad_server, :location_search)

    Application.put_env(:awrad_server, :location_search,
      req_options: [plug: {Req.Test, __MODULE__}]
    )

    on_exit(fn ->
      if previous do
        Application.put_env(:awrad_server, :location_search, previous)
      else
        Application.delete_env(:awrad_server, :location_search)
      end
    end)

    :ok
  end

  setup :register_and_log_in_user

  test "lets the browser choose a named place while storing coordinates for calculations", %{
    conn: conn,
    user: user
  } do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.query_params["q"] == "Bengaluru"

      Req.Test.json(conn, [
        %{
          "lat" => "12.9767936",
          "lon" => "77.5900820",
          "name" => "Bengaluru",
          "display_name" => "Bengaluru, Bangalore North, Karnataka, India",
          "address" => %{
            "city" => "Bengaluru",
            "state" => "Karnataka",
            "country" => "India"
          }
        }
      ])
    end)

    {:ok, view, _html} = live(conn, ~p"/home")

    render_submit(element(view, "#location-search"), %{"query" => "Bengaluru"})

    assert has_element?(view, "#location-results")
    assert has_element?(view, "#location-result-0", "Bengaluru")

    render_click(element(view, "#location-result-0"))

    assert has_element?(view, "#browser-location", "Bengaluru, Karnataka, India")
    refute has_element?(view, ".awrad-device-context-value", "12.9767936")

    assert %DeviceContext{
             location_name: "Bengaluru, Karnataka, India",
             latitude: 12.9767936,
             longitude: 77.590082
           } = Repo.get_by!(DeviceContext, user_id: user.id)
  end
end
