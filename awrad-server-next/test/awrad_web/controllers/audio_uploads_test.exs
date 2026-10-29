defmodule AwradWeb.AudioUploadsTest do
  @moduledoc """
  `create_audio_upload` and `complete_audio_upload` over HTTP, against
  contracts/api/paths/audio.yaml: every status and code, the signed link's
  shape, idempotency by `asset_id`, the quota, and confirming against the
  stored object (`Awrad.Audio.FakeStorage`). The upload rules themselves are
  the fixture runner's (test/awrad/audio/).
  """
  use AwradWeb.ConnCase, async: true

  import Awrad.AccountsFixtures
  import Awrad.AudioFixtures
  import AwradWeb.Contract

  alias Awrad.Audio.{Asset, FakeStorage}
  alias Awrad.Repo

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

  defp create(conn, body), do: post(conn, ~p"/api/v1/audio_uploads", Jason.encode!(body))
  defp complete(conn, asset_id), do: post(conn, "/api/v1/audio_uploads/#{asset_id}/complete")

  defp key(user, body), do: Asset.object_key(user.id, body["asset_id"])

  # The client's PUT: the bytes land in storage as R2 would keep them.
  defp upload!(user, body, bytes), do: FakeStorage.put_object(key(user, body), bytes)

  describe "create_audio_upload" do
    test "201: a pending upload with a signed PUT link valid for 15 minutes",
         %{conn: conn, grant: grant, user: user} do
      bytes = recording()
      body = upload_body(bytes)
      before = DateTime.utc_now(:second)

      conn = conn |> bearer(grant) |> create(body)
      response = assert_conforms(conn, "create_audio_upload")
      assert conn.status == 201
      assert get_resp_header(conn, "cache-control") == ["no-store"]

      checksum = Base.encode64(:crypto.hash(:sha256, bytes))

      assert response["asset_id"] == body["asset_id"]

      assert response["upload_headers"] == %{
               "content-type" => "audio/mpeg",
               "x-amz-checksum-sha256" => checksum
             }

      url = URI.parse(response["upload_url"])
      assert url.scheme == "https"
      assert url.host == "test-account.r2.cloudflarestorage.com"
      assert url.path == "/awrad-private-dhikr/users/#{user.id}/audio/#{body["asset_id"]}"

      query = URI.decode_query(url.query)
      {:ok, signed_at, 0} = DateTime.from_iso8601(response["expires_at"])
      date = Calendar.strftime(DateTime.add(signed_at, -15, :minute), "%Y%m%d")

      assert %{
               "X-Amz-Algorithm" => "AWS4-HMAC-SHA256",
               "X-Amz-Credential" => credential,
               "X-Amz-Expires" => "900",
               "X-Amz-SignedHeaders" => "content-type;host;x-amz-checksum-sha256",
               "X-Amz-Signature" => signature
             } = query

      assert credential == "TESTACCESSKEY/#{date}/auto/s3/aws4_request"
      assert signature =~ ~r/\A[0-9a-f]{64}\z/
      refute response["upload_url"] =~ "test-secret-access-key"
      assert DateTime.diff(signed_at, before) in 900..901

      assert %Asset{status: "pending", byte_size: 2048} = row(user.id, body["asset_id"])
    end

    test "200 for a repeat: a fresh link while pending, the asset once ready, counted once",
         %{conn: conn, grant: grant, user: user} do
      bytes = recording()
      body = upload_body(bytes)

      assert conn |> bearer(grant) |> create(body) |> json_response(201)

      repeat = conn |> bearer(grant) |> create(body)
      assert %{"upload_url" => _} = assert_conforms(repeat, "create_audio_upload")
      assert repeat.status == 200

      usage = conn |> bearer(grant) |> get(~p"/api/v1/audio_assets/usage") |> json_response(200)
      assert usage["used_bytes"] == 2048

      upload!(user, body, bytes)
      assert conn |> bearer(grant) |> complete(body["asset_id"]) |> json_response(200)

      ready = conn |> bearer(grant) |> create(body)
      assert %{"asset" => asset} = assert_conforms(ready, "create_audio_upload")
      assert ready.status == 200
      assert %{"asset_id" => _, "status" => "ready", "byte_size" => 2048} = asset
    end

    test "201 for a browser with its cookie session and CSRF token, Idempotency-Key ignored",
         %{conn: conn, user: user} do
      {browser, csrf} = sign_in_browser(conn, user)
      body = upload_body(recording())

      for status <- [201, 200] do
        conn =
          browser
          |> browser_request(csrf)
          |> put_req_header("x-awrad-account", user.id)
          |> put_req_header("idempotency-key", Awrad.UUIDv7.generate())
          |> create(body)

        assert assert_conforms(conn, "create_audio_upload")["asset_id"] == body["asset_id"]
        assert conn.status == status
      end
    end

    test "409 asset_id_in_use for a different body, or an ID another account uses",
         %{conn: conn, grant: grant} do
      body = upload_body(recording())
      assert conn |> bearer(grant) |> create(body) |> json_response(201)

      for changed <- [
            %{"byte_size" => 4096},
            %{"content_type" => "audio/mp4"},
            %{"sha256" => sha256("other")}
          ] do
        conn = conn |> bearer(grant) |> create(Map.merge(body, changed))
        assert assert_conforms(conn, "create_audio_upload")["code"] == "asset_id_in_use"
        assert conn.status == 409
      end

      other = grant_fixture()
      conn = conn |> bearer(other) |> create(body)
      assert assert_conforms(conn, "create_audio_upload")["code"] == "asset_id_in_use"
    end

    test "the upload rules, in order: 415, 422 invalid_size, 413, 422 storage_full",
         %{conn: conn, grant: grant, user: user} do
      cases = [
        {%{"content_type" => "audio/wav", "byte_size" => 0}, 415, "unsupported_audio_type"},
        {%{"content_type" => "AUDIO/MPEG"}, 415, "unsupported_audio_type"},
        {%{"byte_size" => 0}, 422, "invalid_size"},
        {%{"byte_size" => 10_000_001}, 413, "file_too_large"}
      ]

      for {overrides, status, code} <- cases do
        conn = conn |> bearer(grant) |> create(upload_body(recording(), overrides))
        assert assert_conforms(conn, "create_audio_upload")["code"] == code
        assert conn.status == status
      end

      # 499,999,000 bytes held: 1,000 more is allowed, 1,001 isn't.
      for _ <- 1..49, do: asset!(user.id, bytes: <<0>>, object?: false) |> grow(10_000_000)
      asset!(user.id, status: "pending", bytes: <<0>>, object?: false) |> grow(9_999_000)

      full = conn |> bearer(grant) |> create(upload_body(recording(1001)))
      problem = assert_conforms(full, "create_audio_upload")
      assert full.status == 422

      assert %{
               "code" => "storage_full",
               "used_bytes" => 499_999_000,
               "limit_bytes" => 500_000_000
             } =
               problem

      assert conn |> bearer(grant) |> create(upload_body(recording(1000))) |> json_response(201)
    end

    test "400 malformed_request for a bad X-Awrad-Account or a body that breaks the schema",
         %{conn: conn, grant: grant} do
      body = upload_body(recording())

      for account <- [:none, "not-an-id", String.upcase(grant.user.id)] do
        conn = conn |> bearer(grant, account) |> create(body)
        assert assert_conforms(conn, "create_audio_upload")["code"] == "malformed_request"
      end

      for bad <- [
            %{"asset_id" => "not-a-uuid"},
            %{"asset_id" => String.upcase(body["asset_id"])},
            %{"sha256" => String.upcase(body["sha256"])},
            %{"sha256" => "abc"},
            %{"byte_size" => -1},
            %{"byte_size" => 1.5},
            %{"byte_size" => "2048"},
            %{"content_type" => String.duplicate("a", 256)},
            %{"extra" => true}
          ] do
        conn = conn |> bearer(grant) |> create(Map.merge(body, bad))
        assert assert_conforms(conn, "create_audio_upload")["code"] == "malformed_request"
      end

      missing = conn |> bearer(grant) |> create(Map.delete(body, "sha256"))
      assert assert_conforms(missing, "create_audio_upload")["code"] == "malformed_request"
      assert Repo.aggregate(Asset, :count) == 0
    end

    test "401 without a credential, 403 for a cookie without CSRF, 409 for another account",
         %{conn: conn, grant: grant, user: user} do
      body = upload_body(recording())

      anonymous = conn |> json_conn([{"x-awrad-account", user.id}]) |> create(body)
      assert assert_conforms(anonymous, "create_audio_upload")["code"] == "unauthenticated"

      {browser, _csrf} = sign_in_browser(conn, user)

      no_csrf =
        browser |> next_request() |> json_conn([{"x-awrad-account", user.id}]) |> create(body)

      assert assert_conforms(no_csrf, "create_audio_upload")["code"] == "csrf_token_invalid"

      mismatch = conn |> bearer(grant, user_fixture().id) |> create(body)
      assert assert_conforms(mismatch, "create_audio_upload")["code"] == "account_mismatch"
      assert mismatch.status == 409
      assert Repo.aggregate(Asset, :count) == 0
    end
  end

  describe "complete_audio_upload" do
    setup %{conn: conn, grant: grant} do
      bytes = recording()
      body = upload_body(bytes)
      conn |> bearer(grant) |> create(body) |> json_response(201)
      %{bytes: bytes, body: body}
    end

    test "200: the stored object matches; completing again returns the asset again",
         %{conn: conn, grant: grant, user: user, bytes: bytes, body: body} do
      upload!(user, body, bytes)

      for _ <- 1..2 do
        conn = conn |> bearer(grant) |> complete(body["asset_id"])
        %{"asset" => asset} = assert_conforms(conn, "complete_audio_upload")

        assert %{
                 "asset_id" => asset_id,
                 "byte_size" => 2048,
                 "content_type" => "audio/mpeg",
                 "status" => "ready",
                 "created_at" => _
               } = asset

        assert asset_id == body["asset_id"]
      end

      assert %Asset{status: "ready", ready_at: %DateTime{}} = row(user.id, body["asset_id"])
    end

    test "409 upload_incomplete before the PUT; it completes once the object is there",
         %{conn: conn, grant: grant, user: user, bytes: bytes, body: body} do
      early = conn |> bearer(grant) |> complete(body["asset_id"])
      assert assert_conforms(early, "complete_audio_upload")["code"] == "upload_incomplete"
      assert early.status == 409

      upload!(user, body, bytes)
      assert conn |> bearer(grant) |> complete(body["asset_id"]) |> json_response(200)
    end

    test "422 upload_mismatch deletes the object and the upload",
         %{conn: conn, grant: grant, user: user, bytes: bytes, body: first} do
      reserve = fn ->
        body = upload_body(bytes)
        conn |> bearer(grant) |> create(body) |> json_response(201)
        body
      end

      for {body, stored, detail} <- [
            {first, [byte_size: 2000], "the stored object is 2000 bytes, not 2048"},
            {reserve.(), [content_type: "audio/mp4"],
             "the stored object's content type isn't audio/mpeg"},
            {reserve.(), [checksum_sha256: Base.encode64(:crypto.hash(:sha256, "other"))],
             "the stored object's SHA-256 isn't the upload's"},
            {reserve.(), [checksum_sha256: nil], "the stored object's SHA-256 isn't the upload's"}
          ] do
        FakeStorage.put_object(key(user, body), bytes, stored)

        conn = conn |> bearer(grant) |> complete(body["asset_id"])
        problem = assert_conforms(conn, "complete_audio_upload")
        assert %{"code" => "upload_mismatch", "detail" => ^detail} = problem
        assert conn.status == 422
        refute FakeStorage.object?(key(user, body))

        # Gone for the client: complete is 404, and it no longer counts.
        again = conn |> bearer(grant) |> complete(body["asset_id"])
        assert assert_conforms(again, "complete_audio_upload")["code"] == "not_found"
      end

      usage = conn |> bearer(grant) |> get(~p"/api/v1/audio_assets/usage") |> json_response(200)
      assert usage["used_bytes"] == 0
    end

    test "404 for an unknown asset_id, another account's, or not an ID",
         %{conn: conn, grant: grant, user: user, bytes: bytes, body: body} do
      upload!(user, body, bytes)
      other = grant_fixture()

      for {grant, asset_id} <- [
            {grant, Awrad.UUIDv7.generate()},
            {other, body["asset_id"]},
            {grant, "not-an-id"},
            {grant, String.upcase(body["asset_id"])}
          ] do
        conn = conn |> bearer(grant) |> complete(asset_id)
        assert assert_conforms(conn, "complete_audio_upload")["code"] == "not_found"
        assert conn.status == 404
      end

      assert %Asset{status: "pending"} = row(user.id, body["asset_id"])
    end

    test "400, 401, 403 and 409 account_mismatch, with nothing changed",
         %{conn: conn, grant: grant, user: user, bytes: bytes, body: body} do
      upload!(user, body, bytes)

      no_header = conn |> bearer(grant, :none) |> complete(body["asset_id"])
      assert assert_conforms(no_header, "complete_audio_upload")["code"] == "malformed_request"

      anonymous = conn |> json_conn([{"x-awrad-account", user.id}]) |> complete(body["asset_id"])
      assert assert_conforms(anonymous, "complete_audio_upload")["code"] == "unauthenticated"

      {browser, csrf} = sign_in_browser(conn, user)

      no_csrf =
        browser
        |> next_request()
        |> json_conn([{"x-awrad-account", user.id}])
        |> complete(body["asset_id"])

      assert assert_conforms(no_csrf, "complete_audio_upload")["code"] == "csrf_token_invalid"

      mismatch = conn |> bearer(grant, user_fixture().id) |> complete(body["asset_id"])
      assert assert_conforms(mismatch, "complete_audio_upload")["code"] == "account_mismatch"

      assert %Asset{status: "pending"} = row(user.id, body["asset_id"])

      cookie =
        browser
        |> browser_request(csrf)
        |> put_req_header("x-awrad-account", user.id)
        |> complete(body["asset_id"])

      assert assert_conforms(cookie, "complete_audio_upload")["asset"]["status"] == "ready"
    end
  end

  # Sets a stored upload's declared size, for quota tests.
  defp grow(%Asset{} = asset, byte_size) do
    asset |> Ecto.Changeset.change(byte_size: byte_size) |> Repo.update!()
  end
end
