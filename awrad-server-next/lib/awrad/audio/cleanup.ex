defmodule Awrad.Audio.Cleanup do
  @moduledoc """
  The cleanup job's work (`contracts/audio/v1/README.md`, "Cleanup"), in two
  steps. `Awrad.Audio.Cleaner` runs it every 10 minutes; tests call
  `Awrad.Audio.clean/1` on demand.

  **Mark.** Three conditional updates turn rows into `deleting`, each in one
  statement, so a row a request is changing at the same time is re-checked
  under its lock:

    * every row of a deleted account (`user_id` is `NULL`), from when its
      latest upload link has expired;
    * a pending upload reserved more than 24 hours ago;
    * a ready asset no active custom dhikr names (`referenced` is false) whose
      `last_referenced_at` is more than 24 hours ago.

  Clients never see a `deleting` row: it isn't an asset, doesn't count against
  the quota, and its `asset_id` stays in use until the row goes.

  **Sweep.** For each `deleting` row whose `delete_after` has passed: delete
  the object, then the row. When R2 fails, the row stays and the next run
  tries again, so no object is ever forgotten.
  """

  import Ecto.Query

  require Logger

  alias Awrad.Audio.{Asset, Storage}
  alias Awrad.Repo

  @grace_hours 24
  @sweep_batch 500

  @type result :: %{
          marked: non_neg_integer(),
          deleted: non_neg_integer(),
          failed: non_neg_integer()
        }

  @doc "Marks what's due at `now`, then deletes the objects and rows that may go."
  @spec run(DateTime.t()) :: result()
  def run(now) do
    marked = mark(now)
    {deleted, failed} = sweep(now)
    %{marked: marked, deleted: deleted, failed: failed}
  end

  defp mark(now) do
    cutoff = DateTime.add(now, -@grace_hours, :hour)

    {orphaned, _} =
      Repo.update_all(
        from(a in Asset,
          where: is_nil(a.user_id) and a.status != "deleting",
          update: [
            set: [
              status: "deleting",
              delete_after:
                fragment("GREATEST(?, ?)", type(^now, :utc_datetime), a.upload_expires_at),
              updated_at: ^now
            ]
          ]
        ),
        []
      )

    {abandoned, _} =
      Repo.update_all(
        from(a in Asset, where: a.status == "pending" and a.inserted_at < ^cutoff),
        set: [status: "deleting", delete_after: now, updated_at: now]
      )

    {unreferenced, _} =
      Repo.update_all(
        from(a in Asset,
          where: a.status == "ready" and not a.referenced and a.last_referenced_at < ^cutoff
        ),
        set: [status: "deleting", delete_after: now, updated_at: now]
      )

    orphaned + abandoned + unreferenced
  end

  defp sweep(now) do
    from(a in Asset,
      where: a.status == "deleting" and a.delete_after <= ^now,
      order_by: a.delete_after,
      limit: @sweep_batch,
      select: {a.id, a.object_key}
    )
    |> Repo.all()
    |> Enum.reduce({0, 0}, fn {id, key}, {deleted, failed} ->
      case Storage.delete(key) do
        :ok ->
          Repo.delete_all(from(a in Asset, where: a.id == ^id and a.status == "deleting"))
          {deleted + 1, failed}

        {:error, reason} ->
          Logger.warning(
            "audio object of asset row #{id} not deleted (#{Storage.Error.describe(reason)}); " <>
              "retrying on the next run"
          )

          {deleted, failed + 1}
      end
    end)
  end
end
