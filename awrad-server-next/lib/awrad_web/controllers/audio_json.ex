defmodule AwradWeb.AudioJSON do
  @moduledoc """
  The audio operations' responses (`contracts/api/paths/audio.yaml`,
  `contracts/audio/v1/audio.schema.json`), mapped field by field.
  """

  @doc "A pending upload's signed `PUT` link (`$defs/upload`)."
  @spec upload(Awrad.Audio.upload()) :: map()
  def upload(%{asset_id: asset_id, url: url, headers: headers, expires_at: expires_at}) do
    %{
      asset_id: asset_id,
      upload_url: url,
      upload_headers: headers,
      expires_at: instant(expires_at)
    }
  end

  @doc "A ready asset (`$defs/asset_response`)."
  @spec asset(Awrad.Audio.asset()) :: map()
  def asset(%{asset_id: asset_id, byte_size: byte_size, content_type: type, created_at: at}) do
    %{
      asset: %{
        asset_id: asset_id,
        byte_size: byte_size,
        content_type: type,
        status: "ready",
        created_at: instant(at)
      }
    }
  end

  @doc "A signed `GET` link (`$defs/download`)."
  @spec download(Awrad.Audio.download()) :: map()
  def download(%{url: url, expires_at: expires_at}),
    do: %{url: url, expires_at: instant(expires_at)}

  @doc "Storage used (`$defs/usage`)."
  @spec usage(%{used_bytes: non_neg_integer(), limit_bytes: pos_integer()}) :: map()
  def usage(%{used_bytes: used, limit_bytes: limit}), do: %{used_bytes: used, limit_bytes: limit}

  defp instant(%DateTime{} = at), do: at |> DateTime.truncate(:second) |> DateTime.to_iso8601()
end
