defmodule Awrad.Audio.References do
  @moduledoc """
  What the change queue asks of recordings (`contracts/sync/v1/README.md`,
  rule 5): whether a custom dhikr document may name an asset, and which assets
  active custom dhikrs name.

  Both run inside the change queue's batch transaction. `check/2` locks the
  asset's row (`FOR UPDATE`) until the batch commits, so the cleanup job can't
  mark an asset for deletion between the check and the write that names it:
  its update waits for the lock, then sees the asset referenced.
  """

  import Ecto.Query

  alias Awrad.Audio.Asset
  alias Awrad.Repo

  @doc """
  `:ok` when the uploaded `audio` of a document names a ready asset of
  `user_id` with the same `byte_size` and `content_type`; otherwise
  `{:error, :audio_not_found}`, or `{:error, {:audio_mismatch, members}}`
  with the disagreeing members, sorted. `duration_ms` isn't compared.
  """
  @spec check(Ecto.UUID.t(), map()) ::
          :ok | {:error, :audio_not_found | {:audio_mismatch, [String.t(), ...]}}
  def check(user_id, %{"asset_id" => asset_id} = audio) do
    asset =
      Repo.one(
        from a in Asset,
          where: a.user_id == ^user_id and a.asset_id == ^asset_id and a.status == "ready",
          lock: "FOR UPDATE"
      )

    if asset, do: compare(asset, audio), else: {:error, :audio_not_found}
  end

  defp compare(%Asset{} = asset, audio) do
    members =
      for {member, value} <- [
            {"byte_size", asset.byte_size},
            {"content_type", asset.content_type}
          ],
          audio[member] != value,
          do: member

    if members == [], do: :ok, else: {:error, {:audio_mismatch, members}}
  end

  @doc """
  Records whether each asset of `user_id` is now named by an active custom
  dhikr, and that this changed at `now` (`last_referenced_at`). The cleanup
  job deletes a ready asset only once it's been unreferenced for 24 hours.
  """
  @spec note(Ecto.UUID.t(), %{Ecto.UUID.t() => boolean()}, DateTime.t()) :: :ok
  def note(user_id, referenced, now) do
    for {asset_id, referenced?} <- referenced do
      Repo.update_all(
        from(a in Asset,
          where: a.user_id == ^user_id and a.asset_id == ^asset_id and a.status == "ready"
        ),
        set: [referenced: referenced?, last_referenced_at: now, updated_at: now]
      )
    end

    :ok
  end
end
