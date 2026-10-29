defmodule Awrad.Sync do
  @moduledoc """
  The change queue (slice 3b, root ADR-2026-10-28 "The change queue",
  `contracts/sync/v1/`): how a user's custom dhikrs, tags and per-dhikr
  records move between their phones, the web and the server.

  The only entry point to the context. Ownership is the `user_id` the caller
  authenticated; nothing here reads an account from the request.

    * `validate_batch/1`: the batch envelope (a 422 when it's wrong).
    * `apply_batch/2`: applies the commands in order, one receipt each.
    * `changes/3`: one page of the changes feed.
    * `prune/1`: drops receipts older than 90 days.
  """

  use Boundary, deps: [Awrad, Awrad.Audio, Awrad.Dhikrs], exports: []

  import Ecto.Query

  alias Awrad.Repo
  alias Awrad.Sync.{Batch, Commands, Feed, Receipt}

  @receipt_days 90

  @typedoc "A batch's receipts (wire-shaped maps, in command order) and the head revision after it."
  @type batch_result :: Commands.result()

  @typedoc "One page of the changes feed; each change is a wire-shaped map."
  @type page :: Feed.page()

  @typedoc "An envelope error: a JSON Pointer into the body, a code and an English detail."
  @type batch_error :: Batch.error()

  @doc "`:ok`, or every envelope error of the batch's commands."
  @spec validate_batch([term()]) :: :ok | {:error, [batch_error(), ...]}
  defdelegate validate_batch(commands), to: Batch, as: :validate

  @doc """
  Applies an envelope-valid batch for `user_id`. Returns one receipt per
  command, in order, and the account's head revision after the batch.
  """
  @spec apply_batch(Ecto.UUID.t(), [map(), ...]) :: batch_result()
  defdelegate apply_batch(user_id, commands), to: Commands

  @doc "The changes after revision `after_revision`, `limit` (1–500) at a time."
  @spec changes(Ecto.UUID.t(), non_neg_integer(), 1..500) :: page()
  defdelegate changes(user_id, after_revision, limit), to: Feed, as: :page

  @doc "Deletes receipts older than 90 days. Returns how many went."
  @spec prune(DateTime.t()) :: non_neg_integer()
  def prune(now) do
    cutoff = DateTime.add(now, -@receipt_days, :day)
    {count, _} = Repo.delete_all(from(r in Receipt, where: r.inserted_at < ^cutoff))
    count
  end
end
