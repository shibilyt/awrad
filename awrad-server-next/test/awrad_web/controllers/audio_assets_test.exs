defmodule AwradWeb.AudioAssetsTest do
  @moduledoc """
  `get_audio_download` and `get_audio_usage` over HTTP, against
  contracts/api/paths/audio.yaml: every status and code, and the download
  link's shape.
  """
  use AwradWeb.ConnCase, async: true

  import Awrad.AccountsFixtures
  import Awrad.AudioFixtures
  import AwradWeb.Contract

  setup %{conn: conn} do
    user = user_fixture()
    %{user: user, grant: grant_fixture(user), conn: conn}
  end

  defp bearer(conn, grant, account \\ :own) do
    conn = bearer_request(conn, grant)

    case account do
      :own -> put_req_header(conn, "x-awrad-account", grant.user.id)
      :none -> conn
      value -> put_req_header(conn, "x-awrad-account", value)
    end
  end

  defp download(conn, asset_id), do: get(conn, "/api/v1/audio_assets/#{asset_id}/download")
  defp usage(conn), do: get(conn, ~p"/api/v1/audio_assets/usage")

  describe "get_audio_download" do
    test "200: a signed GET link to a ready asset, valid for 10 minutes",
         %{conn: conn, grant: grant, user: user} do
      asset = asset!(user.id)
      before = DateTime.utc_now(:second)

      conn = conn |> bearer(grant) |> download(asset.asset_id)
      %{"url" => url, "expires_at" => expires_at} = assert_conforms(conn, "get_audio_download")
      assert get_resp_header(conn, "cache-control") == ["no-store"]

      url = URI.parse(url)
      assert url.host == "test-account.r2.cloudflarestorage.com"
      assert url.path == "/awrad-private-dhikr/users/#{user.id}/audio/#{asset.asset_id}"

      assert %{
               "X-Amz-Algorithm" => "AWS4-HMAC-SHA256",
               "X-Amz-Expires" => "600",
               "X-Amz-SignedHeaders" => "host",
               "X-Amz-Credential" => "TESTACCESSKEY/" <> _scope
             } = URI.decode_query(url.query)

      {:ok, expires_at, 0} = DateTime.from_iso8601(expires_at)
      assert DateTime.diff(expires_at, before) in 600..601
    end

    test "200 for a browser's cookie session, without CSRF (a GET)",
         %{conn: conn, user: user} do
      asset = asset!(user.id)
      {browser, _csrf} = sign_in_browser(conn, user)

      conn =
        browser
        |> next_request()
        |> put_req_header("x-awrad-account", user.id)
        |> download(asset.asset_id)

      assert %{"url" => _} = assert_conforms(conn, "get_audio_download")
    end

    test "404 for a pending upload, an unknown ID, another account's asset, or not an ID",
         %{conn: conn, grant: grant, user: user} do
      pending = asset!(user.id, status: "pending")
      ready = asset!(user.id)
      other = grant_fixture()

      for {grant, asset_id} <- [
            {grant, pending.asset_id},
            {grant, Awrad.UUIDv7.generate()},
            {other, ready.asset_id},
            {grant, "not-an-id"}
          ] do
        conn = conn |> bearer(grant) |> download(asset_id)
        assert assert_conforms(conn, "get_audio_download")["code"] == "not_found"
        assert conn.status == 404
      end
    end

    test "400 without X-Awrad-Account, 401 without a credential, 409 for another account",
         %{conn: conn, grant: grant, user: user} do
      asset = asset!(user.id)

      no_header = conn |> bearer(grant, :none) |> download(asset.asset_id)
      assert assert_conforms(no_header, "get_audio_download")["code"] == "malformed_request"

      anonymous = conn |> put_req_header("x-awrad-account", user.id) |> download(asset.asset_id)
      assert assert_conforms(anonymous, "get_audio_download")["code"] == "unauthenticated"

      mismatch = conn |> bearer(grant, user_fixture().id) |> download(asset.asset_id)
      assert assert_conforms(mismatch, "get_audio_download")["code"] == "account_mismatch"
      assert mismatch.status == 409
    end
  end

  describe "get_audio_usage" do
    test "200: ready and pending uploads by declared size, and the limit",
         %{conn: conn, grant: grant, user: user} do
      empty = conn |> bearer(grant) |> usage()

      assert assert_conforms(empty, "get_audio_usage") == %{
               "used_bytes" => 0,
               "limit_bytes" => 500_000_000
             }

      asset!(user.id, bytes: recording(3000))
      asset!(user.id, status: "pending", bytes: recording(2000))
      asset!(user.id, status: "deleting", bytes: recording(1000))
      asset!(grant_fixture().user.id, bytes: recording(500))

      conn = conn |> bearer(grant) |> usage()

      assert assert_conforms(conn, "get_audio_usage") == %{
               "used_bytes" => 5000,
               "limit_bytes" => 500_000_000
             }

      assert get_resp_header(conn, "cache-control") == ["no-store"]
    end

    test "400 without X-Awrad-Account, 401 without a credential, 409 for another account",
         %{conn: conn, grant: grant, user: user} do
      no_header = conn |> bearer(grant, "not-an-id") |> usage()
      assert assert_conforms(no_header, "get_audio_usage")["code"] == "malformed_request"

      anonymous = conn |> put_req_header("x-awrad-account", user.id) |> usage()
      assert assert_conforms(anonymous, "get_audio_usage")["code"] == "unauthenticated"

      mismatch = conn |> bearer(grant, user_fixture().id) |> usage()
      assert assert_conforms(mismatch, "get_audio_usage")["code"] == "account_mismatch"
    end
  end
end
