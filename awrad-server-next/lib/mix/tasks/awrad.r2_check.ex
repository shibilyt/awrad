defmodule Mix.Tasks.Awrad.R2Check do
  @shortdoc "Round-trips a small object through the real private audio bucket"

  @moduledoc """
  Checks the private audio bucket end to end with the configured R2 credentials
  (`AWRAD_R2_*`, read by `config/runtime.exs`; locally from
  `awrad-server-next/mise.local.toml`):

    1. reserves a link the way `create_audio_upload` does and `PUT`s a small
       object through it;
    2. confirms it the way `complete_audio_upload` does: `HEAD`, then the
       size, type and SHA-256 comparison;
    3. checks that R2 refuses the same link with other bytes, and with another
       content type;
    4. downloads it through a presigned `GET` link and compares the bytes;
    5. deletes it, and checks it's gone.

  It prints step names and HTTP statuses only: never a link, key or
  credential. The object lives under `r2-check/`, never under `users/`, and is
  deleted even when a step fails. Exits non-zero on any failure.

      mix awrad.r2_check
  """

  use Mix.Task

  # A command-line tool around the domain; nothing depends on it.
  use Boundary, top_level?: true, deps: [Awrad]

  alias Awrad.Audio
  alias Awrad.Audio.Storage

  @requirements ["app.config"]

  @impl Mix.Task
  def run(_args) do
    {:ok, _apps} = Application.ensure_all_started(:req)

    bytes = :crypto.strong_rand_bytes(4096)
    sha256 = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
    expected = %{byte_size: byte_size(bytes), content_type: "audio/mpeg", sha256: sha256}
    key = "r2-check/" <> Awrad.UUIDv7.generate()

    try do
      check(key, bytes, expected)
      Mix.shell().info("R2 check passed")
    after
      Mix.shell().info("cleanup DELETE: #{inspect(Storage.delete(key))}")
    end
  end

  defp check(key, bytes, expected) do
    upload(key, bytes, expected)
    complete(key, expected)
    download(key, bytes)

    step!("DELETE", if(Storage.delete(key) == :ok, do: 204, else: :error), 204)

    case Storage.head(key) do
      :not_found -> Mix.shell().info("HEAD after DELETE: not found")
      other -> fail!("HEAD after DELETE: #{inspect(other)}")
    end
  end

  # The PUT link refuses other bytes (the checksum) and another type (the signature).
  defp upload(key, bytes, expected) do
    put = Storage.presign_put(key, Audio.upload_headers(expected), 900, DateTime.utc_now(:second))
    step!("PUT through the signed link", put_status(put, bytes), 200)
    step!("PUT with other bytes is refused", put_status(put, flip(bytes)), 400)

    wrong_type = %{put | headers: %{put.headers | "content-type" => "audio/mp4"}}
    step!("PUT with another content type is refused", put_status(wrong_type, bytes), 403)
  end

  defp complete(key, expected) do
    case Storage.head(key) do
      {:ok, object} ->
        checksum = if object.checksum_sha256, do: "present", else: "absent"

        Mix.shell().info(
          "HEAD: found; size #{object.byte_size}, type #{object.content_type}, checksum #{checksum}"
        )

        if detail = Audio.object_mismatch(object, expected),
          do: fail!("complete: #{detail}"),
          else: Mix.shell().info("complete: size, type and checksum match")

      other ->
        fail!("HEAD: #{inspect(other)}")
    end
  end

  defp download(key, bytes) do
    get = Storage.presign_get(key, 600, DateTime.utc_now(:second))
    response = Req.get!(get.url, retry: false, raw: true)
    step!("GET through the signed link", response.status, 200)

    if response.body == bytes,
      do: Mix.shell().info("GET: the bytes match"),
      else: fail!("GET: the bytes differ")
  end

  defp put_status(link, body) do
    Req.put!(link.url, body: body, headers: Map.to_list(link.headers), retry: false).status
  end

  defp flip(<<first, rest::binary>>), do: <<Bitwise.bxor(first, 1), rest::binary>>

  defp step!(name, status, status), do: Mix.shell().info("#{name}: #{status}")
  defp step!(name, status, expected), do: fail!("#{name}: #{status}, expected #{expected}")

  @spec fail!(String.t()) :: no_return()
  defp fail!(message), do: Mix.raise("R2 check failed at #{message}")
end
