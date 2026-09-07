defmodule AwradServerWeb.MobileAssociationControllerTest do
  use AwradServerWeb.ConnCase, async: false

  @android_package "app.awrad.awrad_dhikrgoalstracker"
  @android_fingerprint "00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00"

  setup do
    previous = Application.get_env(:awrad_server, :mobile_app_links)

    on_exit(fn ->
      Application.put_env(:awrad_server, :mobile_app_links, previous)
    end)

    :ok
  end

  test "serves an empty iOS association when iOS is not configured", %{conn: conn} do
    configure_mobile_app_links(ios_app_id: nil)

    response =
      conn
      |> get(~p"/.well-known/apple-app-site-association")
      |> json_response(200)

    assert response["applinks"]["apps"] == []
    assert response["applinks"]["details"] == []
  end

  test "keeps Android association available without iOS configuration", %{conn: conn} do
    configure_mobile_app_links(ios_app_id: nil)

    response =
      conn
      |> get(~p"/.well-known/assetlinks.json")
      |> json_response(200)

    assert [%{"target" => %{"package_name" => @android_package}}] = response
  end

  test "serves an empty Android association when Android is not configured", %{conn: conn} do
    configure_mobile_app_links(ios_app_id: nil, android_sha256_cert_fingerprints: [])

    response =
      conn
      |> get(~p"/.well-known/assetlinks.json")
      |> json_response(200)

    assert response == []
  end

  defp configure_mobile_app_links(overrides) do
    Application.put_env(
      :awrad_server,
      :mobile_app_links,
      Keyword.merge(
        [
          ios_app_id: "TESTTEAMID.app.awrad.awrad",
          android_package: @android_package,
          android_sha256_cert_fingerprints: [@android_fingerprint]
        ],
        overrides
      )
    )
  end
end
