defmodule Awrad.AudioFixtures do
  @moduledoc """
  Recordings for tests: request bodies with real SHA-256s, uploads put
  straight into `audio_assets` at a chosen status and time, and their objects
  in `Awrad.Audio.FakeStorage`.
  """

  # Test support sits outside the production boundaries (Awrad, AwradWeb).
  use Boundary, top_level?: true, check: [in: false, out: false]

  alias Awrad.Audio.{Asset, FakeStorage}
  alias Awrad.Repo

  @doc "Some bytes standing in for a recording (`size` of them)."
  @spec recording(pos_integer()) :: binary()
  def recording(size \\ 2048), do: :crypto.strong_rand_bytes(size)

  @doc "SHA-256 in 64 lowercase hex digits."
  @spec sha256(binary()) :: String.t()
  def sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

  @doc "A `create_audio_upload` body for `bytes`, with a new `asset_id`; `overrides` replace members."
  @spec upload_body(binary(), map()) :: map()
  def upload_body(bytes, overrides \\ %{}) do
    Map.merge(
      %{
        "asset_id" => Awrad.UUIDv7.generate(),
        "byte_size" => byte_size(bytes),
        "content_type" => "audio/mpeg",
        "sha256" => sha256(bytes)
      },
      overrides
    )
  end

  @doc """
  An upload of `user_id` stored directly. Options: `:status` (`"ready"`),
  `:bytes`, `:content_type`, `:inserted_at` and `:last_referenced_at` (now),
  `:referenced` (false), `:upload_expires_at` (15 minutes after
  `:inserted_at`), `:delete_after` (for `"deleting"`; `:inserted_at`), and
  `:object?` (true: the object is stored too).
  """
  @spec asset!(Ecto.UUID.t(), keyword()) :: Asset.t()
  def asset!(user_id, opts \\ []) do
    bytes = Keyword.get_lazy(opts, :bytes, &recording/0)
    status = Keyword.get(opts, :status, "ready")
    at = Keyword.get(opts, :inserted_at, DateTime.utc_now(:second))
    asset_id = Keyword.get_lazy(opts, :asset_id, &Awrad.UUIDv7.generate/0)
    content_type = Keyword.get(opts, :content_type, "audio/mpeg")
    key = Asset.object_key(user_id, asset_id)

    if Keyword.get(opts, :object?, true),
      do: FakeStorage.put_object(key, bytes, content_type: content_type)

    Repo.insert!(%Asset{
      user_id: user_id,
      asset_id: asset_id,
      object_key: key,
      byte_size: byte_size(bytes),
      content_type: content_type,
      sha256: sha256(bytes),
      status: status,
      upload_expires_at: Keyword.get(opts, :upload_expires_at, DateTime.add(at, 15, :minute)),
      ready_at: if(status == "ready", do: at),
      referenced: Keyword.get(opts, :referenced, false),
      last_referenced_at: if(status == "ready", do: Keyword.get(opts, :last_referenced_at, at)),
      delete_after: if(status == "deleting", do: Keyword.get(opts, :delete_after, at)),
      inserted_at: at,
      updated_at: at
    })
  end

  @doc "The upload row of `user_id` and `asset_id`, whatever its status, or `nil`."
  @spec row(Ecto.UUID.t() | nil, Ecto.UUID.t()) :: Asset.t() | nil
  def row(nil, asset_id), do: Repo.get_by(Asset, asset_id: asset_id)
  def row(user_id, asset_id), do: Repo.get_by(Asset, user_id: user_id, asset_id: asset_id)
end
