defmodule Awrad.Audio.Uploads do
  @moduledoc """
  Reserving, confirming and downloading recordings, and the storage used
  (`contracts/audio/v1/README.md`, "Uploading", "Playing", "Storage used").

  **Reserving** runs in one transaction holding a per-account advisory lock,
  so two reservations of one account can't both pass the quota or both insert
  the same `asset_id`. An `asset_id` already used is looked at before the
  rules (`Awrad.Audio.Rules`): the account's own with the same body is a
  repeat (a fresh link while pending, the asset once ready); a different body,
  one being deleted, or one another account uses is `asset_id_in_use`.

  **Confirming** reads the object with `HEAD` outside any transaction, then
  flips the row from `pending` to `ready` only if it's still pending, so the
  cleanup job and a second confirmation can't race it. A mismatched object is
  deleted at once, and its row becomes `deleting` until its link has expired
  (`Awrad.Audio.Cleanup` deletes the object again then, in case the link was
  used meanwhile, and the row).
  """

  import Ecto.Query

  alias Awrad.Audio.{Asset, Rules, Storage}
  alias Awrad.Repo

  @put_seconds 15 * 60
  @get_seconds 10 * 60

  @doc "Reserves an upload of `request` for `user_id` (see `Awrad.Audio.reserve/3`)."
  @spec reserve(Ecto.UUID.t(), Awrad.Audio.upload_request(), DateTime.t()) ::
          Awrad.Audio.reserve_result()
  def reserve(user_id, request, now) do
    {:ok, result} =
      Repo.transact(fn ->
        Repo.query!("SELECT pg_advisory_xact_lock(hashtextextended($1, 0))", [
          "audio_assets:" <> user_id
        ])

        {:ok, decide(user_id, request, now)}
      end)

    result
  end

  defp decide(user_id, request, now) do
    case Repo.get_by(Asset, user_id: user_id, asset_id: request.asset_id) do
      nil -> create(user_id, request, now)
      %Asset{} = asset -> repeat(asset, request, now)
    end
  end

  defp create(user_id, request, now) do
    if used_elsewhere?(user_id, request.asset_id) do
      {:error, :asset_id_in_use}
    else
      with :ok <- rules(request, used_bytes(user_id)), do: insert(user_id, request, now)
    end
  end

  defp rules(request, used) do
    case Rules.check(request.byte_size, request.content_type, used) do
      {:error, :storage_full} -> {:error, {:storage_full, used, Rules.limit_bytes()}}
      ok_or_error -> ok_or_error
    end
  end

  defp insert(user_id, request, now) do
    link = put_link(user_id, request, now)

    Repo.insert!(%Asset{
      user_id: user_id,
      asset_id: request.asset_id,
      object_key: Asset.object_key(user_id, request.asset_id),
      byte_size: request.byte_size,
      content_type: request.content_type,
      sha256: request.sha256,
      status: "pending",
      upload_expires_at: link.expires_at
    })

    {:created, upload(request.asset_id, link)}
  end

  defp repeat(%Asset{} = asset, request, now) do
    same? =
      {asset.byte_size, asset.content_type, asset.sha256} ==
        {request.byte_size, request.content_type, request.sha256}

    case asset.status do
      "pending" when same? ->
        link = put_link(asset.user_id, request, now)

        asset
        |> Ecto.Changeset.change(upload_expires_at: link.expires_at)
        |> Repo.update!()

        {:pending, upload(asset.asset_id, link)}

      "ready" when same? ->
        {:ready, Asset.summary(asset)}

      _different_or_deleting ->
        {:error, :asset_id_in_use}
    end
  end

  defp used_elsewhere?(user_id, asset_id) do
    Repo.exists?(
      from a in Asset,
        where: a.asset_id == ^asset_id and (is_nil(a.user_id) or a.user_id != ^user_id)
    )
  end

  defp put_link(user_id, request, now) do
    Storage.presign_put(
      Asset.object_key(user_id, request.asset_id),
      upload_headers(request),
      @put_seconds,
      now
    )
  end

  defp upload(asset_id, link) do
    %{asset_id: asset_id, url: link.url, headers: link.headers, expires_at: link.expires_at}
  end

  @doc """
  The headers a client sends with its `PUT`, which its link is signed with:
  the type, and the SHA-256 in base64 (`x-amz-checksum-sha256`).
  """
  @spec upload_headers(Awrad.Audio.declared()) :: %{String.t() => String.t()}
  def upload_headers(%{content_type: content_type, sha256: sha256}) do
    %{
      "content-type" => content_type,
      "x-amz-checksum-sha256" => sha256 |> Base.decode16!(case: :lower) |> Base.encode64()
    }
  end

  @doc "Confirms a pending upload (see `Awrad.Audio.complete/3`)."
  @spec complete(Ecto.UUID.t(), Ecto.UUID.t(), DateTime.t()) :: Awrad.Audio.complete_result()
  def complete(user_id, asset_id, now) do
    case live(user_id, asset_id) do
      nil -> {:error, :not_found}
      %Asset{status: "ready"} = asset -> {:ok, Asset.summary(asset)}
      %Asset{status: "pending"} = asset -> verify(asset, now)
    end
  end

  defp verify(%Asset{} = asset, now) do
    case Storage.head(asset.object_key) do
      :not_found ->
        {:error, :upload_incomplete}

      {:ok, object} ->
        case object_mismatch(object, asset) do
          nil -> confirm(asset, now)
          detail -> discard(asset, detail, now)
        end

      {:error, reason} ->
        raise Storage.Error, "HEAD of an upload failed: #{Storage.Error.describe(reason)}"
    end
  end

  defp confirm(%Asset{id: id} = asset, now) do
    {count, _} =
      Repo.update_all(from(a in Asset, where: a.id == ^id and a.status == "pending"),
        set: [status: "ready", ready_at: now, last_referenced_at: now, updated_at: now]
      )

    if count == 1,
      do: {:ok, Asset.summary(%{asset | status: "ready", ready_at: now})},
      else: complete(asset.user_id, asset.asset_id, now)
  end

  # The client's link may still work, so the object is deleted now and again
  # by the cleanup job once the link has expired.
  defp discard(%Asset{id: id} = asset, detail, now) do
    delete_after = Enum.max([now, asset.upload_expires_at], DateTime)

    Repo.update_all(from(a in Asset, where: a.id == ^id and a.status == "pending"),
      set: [status: "deleting", delete_after: delete_after, updated_at: now]
    )

    _ = Storage.delete(asset.object_key)
    {:error, {:upload_mismatch, detail}}
  end

  @doc """
  `nil` when a stored object is the upload's (size, `Content-Type` and
  SHA-256), or why it isn't.
  """
  @spec object_mismatch(Storage.object(), Awrad.Audio.declared()) :: String.t() | nil
  def object_mismatch(object, expected) do
    checksum = upload_headers(expected)["x-amz-checksum-sha256"]

    cond do
      object.byte_size != expected.byte_size ->
        "the stored object is #{object.byte_size} bytes, not #{expected.byte_size}"

      object.content_type != expected.content_type ->
        "the stored object's content type isn't #{expected.content_type}"

      object.checksum_sha256 != checksum ->
        "the stored object's SHA-256 isn't the upload's"

      true ->
        nil
    end
  end

  @doc "A download link for a ready asset (see `Awrad.Audio.download/3`)."
  @spec download(Ecto.UUID.t(), Ecto.UUID.t(), DateTime.t()) ::
          {:ok, Awrad.Audio.download()} | {:error, :not_found}
  def download(user_id, asset_id, now) do
    case live(user_id, asset_id) do
      %Asset{status: "ready"} = asset ->
        link = Storage.presign_get(asset.object_key, @get_seconds, now)
        {:ok, %{url: link.url, expires_at: link.expires_at}}

      _pending_or_none ->
        {:error, :not_found}
    end
  end

  @doc "Bytes the account holds: ready assets and pending uploads, by declared size."
  @spec used_bytes(Ecto.UUID.t()) :: non_neg_integer()
  def used_bytes(user_id) do
    from(a in Asset,
      where: a.user_id == ^user_id and a.status in ["pending", "ready"],
      select: type(coalesce(sum(a.byte_size), 0), :integer)
    )
    |> Repo.one!()
  end

  defp live(user_id, asset_id) do
    Repo.one(
      from a in Asset,
        where: a.user_id == ^user_id and a.asset_id == ^asset_id,
        where: a.status in ["pending", "ready"]
    )
  end
end
