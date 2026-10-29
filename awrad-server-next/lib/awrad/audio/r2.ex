defmodule Awrad.Audio.R2 do
  @moduledoc """
  `Awrad.Audio.Storage` on Cloudflare R2's S3 API (server ADR 0011): path-style
  requests to `https://<account>.r2.cloudflarestorage.com/<bucket>/<key>`,
  signed with AWS Signature Version 4 for service `s3` in region `auto`.

    * Presigned links use `Req.Utils.aws_sigv4_url/1` (query-string auth,
      `UNSIGNED-PAYLOAD`). A `PUT` link also signs `content-type` and
      `x-amz-checksum-sha256`, so R2 refuses another type or other bytes.
    * `HEAD` and `DELETE` are Req requests with its `aws_sigv4` step. `HEAD`
      asks for the stored checksum (`x-amz-checksum-mode: ENABLED`).

  Credentials come from `config :awrad, Awrad.Audio.R2` (`account_id`,
  `bucket`, `access_key_id`, `secret_access_key`), which `config/runtime.exs`
  reads from `AWRAD_R2_ACCOUNT_ID`, `AWRAD_R2_PRIVATE_BUCKET`,
  `AWRAD_R2_ACCESS_KEY_ID` and `AWRAD_R2_SECRET_ACCESS_KEY`. They're needed
  only when audio is used: a missing one raises naming the variable, never a
  value. Nothing here logs or returns a credential; clients see signed links
  only.

  `req_options` in the same config are merged into every `HEAD` and `DELETE`
  (tests route them to `Req.Test`).
  """

  @behaviour Awrad.Audio.Storage

  @region "auto"
  @service "s3"

  @variables [
    account_id: "AWRAD_R2_ACCOUNT_ID",
    bucket: "AWRAD_R2_PRIVATE_BUCKET",
    access_key_id: "AWRAD_R2_ACCESS_KEY_ID",
    secret_access_key: "AWRAD_R2_SECRET_ACCESS_KEY"
  ]

  defmodule ConfigError do
    @moduledoc "An R2 setting is missing. The message names the environment variable, never a value."
    defexception [:message]
  end

  @impl Awrad.Audio.Storage
  def presign_put(key, headers, seconds, %DateTime{} = now),
    do: presign(:put, key, headers, seconds, now)

  @impl Awrad.Audio.Storage
  def presign_get(key, seconds, %DateTime{} = now), do: presign(:get, key, %{}, seconds, now)

  @impl Awrad.Audio.Storage
  def head(key) do
    case request(:head, key, [{"x-amz-checksum-mode", "ENABLED"}]) do
      {:ok, %Req.Response{status: 200} = response} -> {:ok, object(response)}
      {:ok, %Req.Response{status: 404}} -> :not_found
      {:ok, %Req.Response{status: status}} -> {:error, {:status, status}}
      {:error, exception} -> {:error, exception}
    end
  end

  @impl Awrad.Audio.Storage
  def delete(key) do
    case request(:delete, key, []) do
      {:ok, %Req.Response{status: status}} when status in [200, 204, 404] -> :ok
      {:ok, %Req.Response{status: status}} -> {:error, {:status, status}}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc "The object's URL: `https://<account>.r2.cloudflarestorage.com/<bucket>/<key>`."
  @spec url(String.t()) :: String.t()
  def url(key) do
    "https://#{setting!(:account_id)}.r2.cloudflarestorage.com/#{setting!(:bucket)}/#{key}"
  end

  defp presign(method, key, headers, seconds, now) do
    now = DateTime.truncate(now, :second)

    signed =
      Req.Utils.aws_sigv4_url(
        access_key_id: setting!(:access_key_id),
        secret_access_key: setting!(:secret_access_key),
        region: @region,
        service: @service,
        datetime: now,
        method: method,
        url: url(key),
        expires: seconds,
        headers: Enum.sort(headers)
      )

    %{url: URI.to_string(signed), headers: headers, expires_at: DateTime.add(now, seconds)}
  end

  defp request(method, key, headers) do
    options =
      [
        method: method,
        url: url(key),
        headers: headers,
        aws_sigv4: [
          access_key_id: setting!(:access_key_id),
          secret_access_key: setting!(:secret_access_key),
          region: @region,
          service: @service
        ],
        retry: false,
        receive_timeout: 15_000
      ]
      |> Keyword.merge(Keyword.get(config(), :req_options, []))

    Req.request(options)
  end

  defp object(%Req.Response{} = response) do
    %{
      byte_size: response |> header("content-length") |> integer(),
      content_type: header(response, "content-type"),
      checksum_sha256: header(response, "x-amz-checksum-sha256")
    }
  end

  defp header(response, name) do
    case Req.Response.get_header(response, name) do
      [value | _] -> value
      [] -> nil
    end
  end

  defp integer(nil), do: 0

  defp integer(value) do
    case Integer.parse(value) do
      {number, ""} when number >= 0 -> number
      _other -> 0
    end
  end

  defp config, do: Application.get_env(:awrad, __MODULE__, [])

  defp setting!(name) do
    case Keyword.get(config(), name) do
      value when is_binary(value) and value != "" ->
        value

      _missing ->
        raise ConfigError,
              "#{Keyword.fetch!(@variables, name)} is not set. Audio storage needs " <>
                Enum.map_join(@variables, ", ", &elem(&1, 1)) <>
                " (awrad-server-next/mise.local.toml locally, the environment in production)."
    end
  end
end
