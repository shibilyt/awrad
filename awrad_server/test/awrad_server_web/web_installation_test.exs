defmodule AwradServerWeb.WebInstallationTest do
  use AwradServerWeb.ConnCase, async: true

  alias AwradServerWeb.WebInstallation

  test "creates a stable server-owned browser installation in the signed session", %{conn: conn} do
    conn = conn |> init_test_session(%{}) |> WebInstallation.call([])
    installation_id = get_session(conn, :web_installation_id)

    assert conn.assigns.web_installation_id == installation_id
    assert {:ok, ^installation_id} = Ecto.UUID.cast(installation_id)

    assert Regex.match?(
             ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/,
             installation_id
           )
  end

  test "reuses the installation for another request", %{conn: conn} do
    installation_id = Ecto.UUID.generate()

    conn =
      conn
      |> init_test_session(%{})
      |> put_session(:web_installation_id, installation_id)
      |> WebInstallation.call([])

    assert conn.assigns.web_installation_id == installation_id
    assert get_session(conn, :web_installation_id) == installation_id
  end

  test "replaces a malformed client-supplied session value", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{})
      |> put_session(:web_installation_id, "not-a-uuid")
      |> WebInstallation.call([])

    refute conn.assigns.web_installation_id == "not-a-uuid"
    assert {:ok, _installation_id} = Ecto.UUID.cast(conn.assigns.web_installation_id)
  end
end
