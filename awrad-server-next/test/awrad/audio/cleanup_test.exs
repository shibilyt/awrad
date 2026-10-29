defmodule Awrad.Audio.CleanupTest do
  @moduledoc """
  The recordings cleanup (`Awrad.Audio.clean/1`, run on demand at a chosen
  time): abandoned uploads, recordings unreferenced for 24 hours (replaced,
  removed, or their dhikr deleted, through the change queue), mismatched
  uploads, deleted accounts' recordings, and R2 failures retried.
  """
  use AwradWeb.ConnCase, async: true

  import Awrad.AccountsFixtures
  import Awrad.AudioFixtures

  alias Awrad.Audio
  alias Awrad.Audio.{Asset, FakeStorage}

  @dhikr %{
    "kind" => "dhikr",
    "arabic" => "سُبْحَانَ ٱللَّهِ",
    "title" => %{"en" => "Subhanallah", "ar" => nil, "ml" => nil},
    "transliteration" => %{"en" => nil, "ml" => nil},
    "translation" => %{"en" => nil, "ar" => nil, "ml" => nil},
    "audio" => nil,
    "references" => []
  }

  setup do
    %{user: user_fixture(), now: DateTime.utc_now(:second)}
  end

  defp hours(now, hours), do: DateTime.add(now, hours, :hour)

  defp gone?(%Asset{} = asset),
    do: is_nil(Awrad.Repo.get(Asset, asset.id)) and not FakeStorage.object?(asset.object_key)

  defp kept?(%Asset{} = asset),
    do: Awrad.Repo.get(Asset, asset.id) != nil and FakeStorage.object?(asset.object_key)

  defp command(op, id, base_version, audio \\ nil) do
    %{
      "command_id" => Awrad.UUIDv7.generate(),
      "entity_type" => "custom_dhikr",
      "entity_id" => id,
      "op" => op,
      "base_version" => base_version
    }
    |> then(&if(op == "put", do: Map.put(&1, "document", %{@dhikr | "audio" => audio}), else: &1))
  end

  defp audio(%Asset{} = asset) do
    %{
      "asset_id" => asset.asset_id,
      "byte_size" => asset.byte_size,
      "content_type" => asset.content_type,
      "duration_ms" => nil
    }
  end

  defp apply!(user, command) do
    %{receipts: [%{"status" => "applied"}]} = Awrad.Sync.apply_batch(user.id, [command])
    :ok
  end

  test "a pending upload goes 24 hours after it was reserved, object and row",
       %{user: user, now: now} do
    old = asset!(user.id, status: "pending", inserted_at: hours(now, -25))
    recent = asset!(user.id, status: "pending", inserted_at: hours(now, -23))
    never_put = asset!(user.id, status: "pending", inserted_at: hours(now, -25), object?: false)

    assert %{marked: 2, deleted: 2, failed: 0} = Audio.clean(now)

    assert gone?(old)
    assert gone?(never_put)
    assert kept?(recent)
  end

  test "a ready asset goes after 24 hours unreferenced; a referenced one stays",
       %{user: user, now: now} do
    unreferenced = asset!(user.id, last_referenced_at: hours(now, -25))
    recently = asset!(user.id, last_referenced_at: hours(now, -23))
    named = asset!(user.id, referenced: true, last_referenced_at: hours(now, -24 * 30))

    assert %{deleted: 1} = Audio.clean(now)

    assert gone?(unreferenced)
    assert kept?(recently)
    assert kept?(named)
  end

  test "replaced, removed and deleted-dhikr recordings go 24 hours later, through the change queue",
       %{user: user, now: now} do
    first = asset!(user.id, inserted_at: hours(now, -48))
    second = asset!(user.id, inserted_at: hours(now, -48))
    dhikr_id = Awrad.UUIDv7.generate()

    # Naming an asset updates its last_referenced_at and keeps it.
    :ok = apply!(user, command("put", dhikr_id, 0, audio(first)))
    assert %Asset{referenced: true} = touched = Awrad.Repo.get!(Asset, first.id)
    assert DateTime.compare(touched.last_referenced_at, hours(now, -1)) == :gt

    # Never named: it goes; named: it stays, however old.
    Audio.clean(hours(now, 48))
    assert kept?(first)
    assert gone?(second)

    # Replaced: the old one goes 24 hours after the replacement.
    third = asset!(user.id)
    :ok = apply!(user, command("put", dhikr_id, 1, audio(third)))
    Audio.clean(hours(now, 23))
    assert kept?(first)
    Audio.clean(hours(now, 25))
    assert gone?(first)
    assert kept?(third)

    # Removed (audio null), then named again within 24 hours: it stays.
    :ok = apply!(user, command("put", dhikr_id, 2, nil))
    :ok = apply!(user, command("put", dhikr_id, 3, audio(third)))
    Audio.clean(hours(now, 25))
    assert kept?(third)

    # The dhikr deleted: its recording goes 24 hours later.
    :ok = apply!(user, command("delete", dhikr_id, 4))
    Audio.clean(hours(now, 23))
    assert kept?(third)
    Audio.clean(hours(now, 25))
    assert gone?(third)
  end

  test "a recording two dhikrs name stays until neither does", %{user: user, now: now} do
    shared = asset!(user.id)
    [one, two] = [Awrad.UUIDv7.generate(), Awrad.UUIDv7.generate()]

    :ok = apply!(user, command("put", one, 0, audio(shared)))
    :ok = apply!(user, command("put", two, 0, audio(shared)))
    :ok = apply!(user, command("delete", one, 1))

    Audio.clean(hours(now, 25))
    assert kept?(shared)

    :ok = apply!(user, command("put", two, 1, nil))
    Audio.clean(hours(now, 25))
    assert gone?(shared)
  end

  test "a mismatched upload's object goes at once, and again once its link has expired",
       %{user: user, now: now} do
    bytes = recording()
    body = upload_body(bytes)

    request = %{
      asset_id: body["asset_id"],
      byte_size: body["byte_size"],
      content_type: body["content_type"],
      sha256: body["sha256"]
    }

    assert {:created, _upload} = Audio.reserve(user.id, request, now)
    key = Asset.object_key(user.id, request.asset_id)
    FakeStorage.put_object(key, bytes, byte_size: 1)

    assert {:error, {:upload_mismatch, _detail}} = Audio.complete(user.id, request.asset_id, now)
    refute FakeStorage.object?(key)
    assert Audio.reserve(user.id, request, now) == {:error, :asset_id_in_use}

    # The link still worked for a while: a late PUT is caught after it expires.
    FakeStorage.put_object(key, bytes)
    Audio.clean(DateTime.add(now, 14, :minute))
    assert %Asset{status: "deleting"} = row(user.id, request.asset_id)

    Audio.clean(DateTime.add(now, 16, :minute))
    assert row(user.id, request.asset_id) == nil
    refute FakeStorage.object?(key)
  end

  @tag :capture_log
  test "an R2 failure keeps the row, and the next run deletes the object", %{user: user, now: now} do
    abandoned = asset!(user.id, status: "pending", inserted_at: hours(now, -25))
    FakeStorage.fail_deletes(abandoned.object_key)

    assert %{marked: 1, deleted: 0, failed: 1} = Audio.clean(now)
    assert kept?(abandoned)
    assert %Asset{status: "deleting"} = Awrad.Repo.get!(Asset, abandoned.id)

    FakeStorage.fail_deletes(abandoned.object_key, false)
    assert %{marked: 0, deleted: 1, failed: 0} = Audio.clean(now)
    assert gone?(abandoned)
  end

  @tag :capture_log
  test "deleting the account deletes every object of it, retrying R2 failures",
       %{conn: conn, user: user, now: now} do
    an_hour_ago = hours(now, -1)
    ready = asset!(user.id, inserted_at: an_hour_ago)
    named = asset!(user.id, referenced: true, inserted_at: an_hour_ago)
    failing = asset!(user.id, inserted_at: an_hour_ago)
    # Reserved just now: its link works for 15 more minutes.
    pending = asset!(user.id, status: "pending", inserted_at: now)
    someone_else = asset!(user_fixture().id)
    FakeStorage.fail_deletes(failing.object_key)

    conn
    |> bearer_request(grant_fixture(user))
    |> post(~p"/api/v1/account/delete", Jason.encode!(%{current_password: valid_password()}))
    |> response(204)

    # The rows outlive the account only as cleanup work: no account, the object key.
    assert %Asset{user_id: nil} = Awrad.Repo.get!(Asset, ready.id)

    assert %{deleted: 2, failed: 1} = Audio.clean(now)
    assert gone?(ready)
    assert gone?(named)
    assert kept?(failing)
    assert kept?(pending)

    FakeStorage.fail_deletes(failing.object_key, false)
    assert %{deleted: 2} = Audio.clean(DateTime.add(now, 16, :minute))
    assert gone?(failing)
    assert gone?(pending)
    assert kept?(someone_else)
  end
end
