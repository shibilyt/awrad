defmodule Awrad.Sync.SyncReceiptsTest do
  @moduledoc """
  contracts/sync/v1/fixtures/sync_receipts.json, one test per case: the
  case's state goes into the database for a fresh account, the batch goes
  through `Awrad.Sync.apply_batch/2`, and the receipts, head, changes, aliases
  and stored receipts must be the expected ones.
  """
  use Awrad.DataCase, async: true

  import Awrad.AccountsFixtures

  alias Awrad.Fixtures
  alias Awrad.Fixtures.Sync, as: SyncState

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("sync/v1", "sync_receipts") do
    @given given
    @expect expect
    test id do
      %{id: user_id} = user_fixture()
      %{"state" => state, "batch" => batch} = @given
      :ok = SyncState.put_state!(user_id, state)

      assert Awrad.Sync.validate_batch(batch) == :ok

      result = Awrad.Sync.apply_batch(user_id, batch)

      assert result.receipts == @expect["receipts"]
      assert result.head_revision == @expect["head_revision"]
      assert SyncState.head_revision(user_id) == @expect["head_revision"]

      assert SyncState.changes_after(user_id, state["head_revision"]) == @expect["changes"]
      assert SyncState.tag_aliases(user_id) == @expect["tag_aliases"]
      assert SyncState.stored_receipts(user_id) == @expect["stored_receipts"]
    end
  end
end
