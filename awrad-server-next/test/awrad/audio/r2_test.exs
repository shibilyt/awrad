defmodule Awrad.Audio.R2Test do
  @moduledoc """
  The R2 client (`Awrad.Audio.R2`) without R2: presigned links checked against
  an independent SigV4 computation (AWS's query-string authentication), and
  `HEAD` and `DELETE` routed to `Req.Test` (`config/test.exs`). The real
  bucket is `mix awrad.r2_check`'s.
  """
  # Not async: one test swaps the R2 settings, which are global.
  use ExUnit.Case, async: false

  alias Awrad.Audio.R2

  @key "users/0192f0e0-0000-7000-8000-00000000000a/audio/0192f0e0-0000-7000-8000-000000000001"
  @path "/awrad-private-dhikr/" <> @key
  @host "test-account.r2.cloudflarestorage.com"
  @at ~U[2026-10-29 08:00:00Z]

  @headers %{
    "content-type" => "audio/mpeg",
    "x-amz-checksum-sha256" => "eVllD5+mm2J5s2lOJQYFnLZwYswPfprSejRlKNNB5bw="
  }

  describe "presigned links" do
    test "PUT: path-style URL, 15 minutes, signed with the type and the checksum" do
      link = R2.presign_put(@key, @headers, 900, @at)

      assert link.headers == @headers
      assert link.expires_at == ~U[2026-10-29 08:15:00Z]

      url = URI.parse(link.url)
      assert {url.scheme, url.host, url.path} == {"https", @host, @path}

      assert url.query ==
               expected_query("PUT", [{"content-type", "audio/mpeg"} | checksum()], 900)
    end

    test "GET: 10 minutes, signed with the host only" do
      link = R2.presign_get(@key, 600, @at)

      assert link.headers == %{}
      assert link.expires_at == ~U[2026-10-29 08:10:00Z]
      assert URI.parse(link.url).query == expected_query("GET", [], 600)
      assert link.url =~ "X-Amz-SignedHeaders=host&"
    end
  end

  describe "HEAD" do
    test "reads the size, type and stored checksum, asking R2 for the checksum" do
      Req.Test.stub(R2, fn conn ->
        assert conn.method == "HEAD"
        assert {conn.host, conn.request_path} == {@host, @path}
        assert Plug.Conn.get_req_header(conn, "x-amz-checksum-mode") == ["ENABLED"]

        [authorization] = Plug.Conn.get_req_header(conn, "authorization")
        date = Calendar.strftime(DateTime.utc_now(), "%Y%m%d")

        assert authorization =~
                 ~r"\AAWS4-HMAC-SHA256 Credential=TESTACCESSKEY/#{date}/auto/s3/aws4_request,SignedHeaders=[a-z0-9;-]*x-amz-checksum-mode[a-z0-9;-]*,Signature=[0-9a-f]{64}\z"

        conn
        |> Plug.Conn.put_resp_header("content-length", "4182733")
        |> Plug.Conn.put_resp_header("content-type", "audio/mpeg")
        |> Plug.Conn.put_resp_header("x-amz-checksum-sha256", @headers["x-amz-checksum-sha256"])
        |> Plug.Conn.send_resp(200, "")
      end)

      assert R2.head(@key) ==
               {:ok,
                %{
                  byte_size: 4_182_733,
                  content_type: "audio/mpeg",
                  checksum_sha256: @headers["x-amz-checksum-sha256"]
                }}
    end

    test "404 is :not_found; anything else is an error" do
      Req.Test.stub(R2, &Plug.Conn.send_resp(&1, 404, ""))
      assert R2.head(@key) == :not_found

      Req.Test.stub(R2, &Plug.Conn.send_resp(&1, 403, ""))
      assert R2.head(@key) == {:error, {:status, 403}}
    end
  end

  describe "DELETE" do
    test "204 and 404 are deleted; 5xx is an error to retry" do
      for {status, result} <- [
            {204, :ok},
            {200, :ok},
            {404, :ok},
            {500, {:error, {:status, 500}}}
          ] do
        Req.Test.stub(R2, fn conn ->
          assert {conn.method, conn.request_path} == {"DELETE", @path}
          assert [_signed] = Plug.Conn.get_req_header(conn, "authorization")
          Plug.Conn.send_resp(conn, status, "")
        end)

        assert R2.delete(@key) == result
      end
    end
  end

  test "a missing setting raises naming its variable, never a value" do
    settings = Application.fetch_env!(:awrad, R2)

    try do
      Application.put_env(:awrad, R2, Keyword.delete(settings, :secret_access_key))

      error = assert_raise R2.ConfigError, fn -> R2.presign_get(@key, 600, @at) end
      assert error.message =~ "AWRAD_R2_SECRET_ACCESS_KEY is not set"
      refute error.message =~ settings[:access_key_id]
      refute error.message =~ settings[:account_id]
    after
      Application.put_env(:awrad, R2, settings)
    end
  end

  # SigV4 query-string authentication, computed here from the AWS
  # specification rather than by Req: the canonical request (with
  # UNSIGNED-PAYLOAD), the string to sign and the derived key.
  defp expected_query(method, headers, seconds) do
    headers = Enum.sort([{"host", @host} | headers])
    signed_headers = Enum.map_join(headers, ";", &elem(&1, 0))
    scope = "20261029/auto/s3/aws4_request"

    query =
      [
        {"X-Amz-Algorithm", "AWS4-HMAC-SHA256"},
        {"X-Amz-Credential", "TESTACCESSKEY/" <> scope},
        {"X-Amz-Date", "20261029T080000Z"},
        {"X-Amz-Expires", Integer.to_string(seconds)},
        {"X-Amz-SignedHeaders", signed_headers}
      ]
      |> Enum.map_join("&", fn {name, value} ->
        "#{name}=#{URI.encode(value, &URI.char_unreserved?/1)}"
      end)

    canonical =
      Enum.join(
        [
          method,
          @path,
          query,
          Enum.map_join(headers, "", fn {name, value} -> "#{name}:#{value}\n" end),
          signed_headers,
          "UNSIGNED-PAYLOAD"
        ],
        "\n"
      )

    to_sign =
      Enum.join(
        ["AWS4-HMAC-SHA256", "20261029T080000Z", scope, hex(:crypto.hash(:sha256, canonical))],
        "\n"
      )

    key =
      Enum.reduce(["20261029", "auto", "s3", "aws4_request"], "AWS4" <> secret(), &hmac(&2, &1))

    query <> "&X-Amz-Signature=" <> hex(hmac(key, to_sign))
  end

  defp checksum, do: [{"x-amz-checksum-sha256", @headers["x-amz-checksum-sha256"]}]
  defp secret, do: Application.fetch_env!(:awrad, R2)[:secret_access_key]
  defp hmac(key, data), do: :crypto.mac(:hmac, :sha256, key, data)
  defp hex(bytes), do: Base.encode16(bytes, case: :lower)
end
