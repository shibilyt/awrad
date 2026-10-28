defmodule Awrad.Sync.SyncChangesFeedTest do
  @moduledoc """
  contracts/sync/v1/fixtures/sync_changes_feed.json, one test per case: the
  entities and head go into the database for a fresh account, and
  `Awrad.Sync.changes/3` must return the expected page.
  """
  use Awrad.DataCase, async: true

  import Awrad.AccountsFixtures

  alias Awrad.Fixtures
  alias Awrad.Fixtures.Sync, as: SyncState

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("sync/v1", "sync_changes_feed") do
    @given given
    @expect expect
    test id do
      %{id: user_id} = user_fixture()
      :ok = SyncState.put_state!(user_id, @given)

      page = Awrad.Sync.changes(user_id, @given["after"], @given["limit"])

      assert %{
               "changes" => page.changes,
               "next_after" => page.next_after,
               "has_more" => page.has_more,
               "head_revision" => page.head_revision
             } == @expect
    end
  end

  test "an account without a head reads an empty page at revision 0" do
    %{id: user_id} = user_fixture()

    assert Awrad.Sync.changes(user_id, 0, 200) ==
             %{changes: [], next_after: 0, has_more: false, head_revision: 0}
  end

  test "another account's entities never appear" do
    %{id: owner} = user_fixture()
    %{id: other} = user_fixture()

    [first | _] = Fixtures.cases!("sync/v1", "sync_changes_feed")
    :ok = SyncState.put_state!(owner, first["given"])

    assert Awrad.Sync.changes(other, 0, 500).changes == []
  end
end
