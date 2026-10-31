defmodule Awrad.Sync.SyncReceiptsTest do
  @moduledoc """
  contracts/sync/v1/fixtures/sync_receipts.json, one test per case: the
  case's state goes into the database for a fresh account with the state's
  `account_id` (a `practice_policy` or `goal_order` entity_id must equal it),
  the batch goes through `Awrad.Sync.apply_batch/3` on the state's
  `utc_date` (the date the server ends goals on), and the receipts, head,
  changes, aliases and stored receipts must be the expected ones.

  Not async: every case names the same account ID, and concurrent sandboxed
  inserts of one primary key would only wait on each other.
  """
  use Awrad.DataCase, async: false

  import Awrad.AccountsFixtures

  alias Awrad.Fixtures
  alias Awrad.Fixtures.Sync, as: SyncState

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("sync/v1", "sync_receipts") do
    @given given
    @expect expect

    test id do
      %{"state" => state, "batch" => batch} = @given
      %{id: user_id} = user_fixture(%{id: state["account_id"]})
      assert user_id == state["account_id"]
      :ok = SyncState.put_state!(user_id, state)

      assert Awrad.Sync.validate_batch(batch) == :ok

      result = Awrad.Sync.apply_batch(user_id, batch, SyncState.utc_date(state))

      assert result.receipts == @expect["receipts"]
      assert result.head_revision == @expect["head_revision"]
      assert SyncState.head_revision(user_id) == @expect["head_revision"]

      assert SyncState.changes_after(user_id, state["head_revision"]) == @expect["changes"]
      assert SyncState.tag_aliases(user_id) == @expect["tag_aliases"]
      assert SyncState.stored_receipts(user_id) == @expect["stored_receipts"]
    end
  end
end
