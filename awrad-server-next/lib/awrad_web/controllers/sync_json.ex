defmodule AwradWeb.SyncJSON do
  @moduledoc """
  The change queue's responses (`contracts/api/paths/sync.yaml`). Receipts and
  changes are already in their wire shape (`contracts/sync/v1/sync.schema.json`):
  receipts are stored as sent, so a duplicate replays its original exactly.
  """

  @doc "`post_sync_commands` 200."
  @spec receipts(Awrad.Sync.batch_result()) :: map()
  def receipts(%{receipts: receipts, head_revision: head_revision}),
    do: %{receipts: receipts, head_revision: head_revision}

  @doc "`list_sync_changes` 200."
  @spec changes(Awrad.Sync.page()) :: map()
  def changes(%{changes: changes, next_after: next, has_more: more, head_revision: head}),
    do: %{changes: changes, next_after: next, has_more: more, head_revision: head}
end
