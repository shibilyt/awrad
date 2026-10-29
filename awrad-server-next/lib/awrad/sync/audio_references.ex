defmodule Awrad.Sync.AudioReferences do
  @moduledoc """
  Custom dhikr documents and the recordings they name (slice 3c,
  `contracts/sync/v1/README.md` rule 5, `Awrad.Audio`).

    * `check/3`: a put whose `audio` names an uploaded recording needs a ready
      asset of the account (`audio_not_found`, `not_found` on
      `/document/audio/asset_id`) with the same `byte_size` and `content_type`
      (`audio_mismatch`, `mismatch` on each disagreeing member, sorted).
      `duration_ms` isn't compared. The asset stays locked until the batch
      commits.
    * `track/3`: after a custom dhikr is written, tells `Awrad.Audio` whether
      the asset its old and new documents named is still named by an active
      custom dhikr, so a replaced or removed recording is deleted after 24
      hours unreferenced, and one that's named stays.
  """

  import Ecto.Query

  alias Awrad.Repo
  alias Awrad.Sync.{Entity, Receipt}

  @doc "`:ok`, or `{:stop, receipt}` for a custom dhikr put naming an asset it may not."
  @spec check(Ecto.UUID.t(), map(), Entity.t() | nil) :: :ok | {:stop, map()}
  def check(user_id, %{"document" => %{"audio" => %{"asset_id" => _} = audio}} = command, entity) do
    case Awrad.Audio.check_reference(user_id, audio) do
      :ok ->
        :ok

      {:error, :audio_not_found} ->
        fields = [%{"field" => "/document/audio/asset_id", "code" => "not_found"}]
        {:stop, Receipt.rejected(command, "audio_not_found", fields, entity)}

      {:error, {:audio_mismatch, members}} ->
        fields =
          for member <- members,
              do: %{"field" => "/document/audio/" <> member, "code" => "mismatch"}

        {:stop, Receipt.rejected(command, "audio_mismatch", fields, entity)}
    end
  end

  def check(_user_id, _command, _entity), do: :ok

  @doc """
  After `command` changed a custom dhikr (whose state before was `entity`),
  records which of the assets named before and after are still named by an
  active custom dhikr of the account.
  """
  @spec track(Ecto.UUID.t(), map(), Entity.t() | nil) :: :ok
  def track(user_id, %{"entity_type" => "custom_dhikr"} = command, entity) do
    before = asset_id(entity && entity.document)
    now = asset_id(command["document"])

    case Enum.uniq(Enum.reject([before, now], &is_nil/1)) do
      [] ->
        :ok

      asset_ids ->
        named = named(user_id, asset_ids)
        referenced = Map.new(asset_ids, &{&1, MapSet.member?(named, &1)})
        Awrad.Audio.note_references(user_id, referenced, DateTime.utc_now(:second))
    end
  end

  def track(_user_id, _command, _entity), do: :ok

  defp asset_id(%{"audio" => %{"asset_id" => asset_id}}), do: asset_id
  defp asset_id(_document), do: nil

  # Which of `asset_ids` an active custom dhikr of the account names.
  defp named(user_id, asset_ids) do
    from(e in Entity,
      where: e.user_id == ^user_id and e.entity_type == "custom_dhikr" and e.state == "active",
      where: fragment("?->'audio'->>'asset_id'", e.document) in ^asset_ids,
      select: fragment("?->'audio'->>'asset_id'", e.document),
      distinct: true
    )
    |> Repo.all()
    |> MapSet.new()
  end
end
