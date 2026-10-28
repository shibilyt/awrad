defmodule Awrad.Sync.ServerLimitsTest do
  @moduledoc """
  The change-queue rules the shared fixtures leave out (contracts/sync/v1/README.md,
  "Limits"): 1,000 active custom dhikrs, 64 KB per document, receipts kept 90
  days, and a payload hash that ignores member order.
  """
  use Awrad.DataCase, async: true

  import Awrad.AccountsFixtures

  alias Awrad.Sync
  alias Awrad.Sync.{Entity, Receipt}

  @dhikr %{
    "kind" => "dhikr",
    "arabic" => "سُبْحَانَ ٱللَّهِ",
    "title" => %{"en" => "Subhanallah", "ar" => nil, "ml" => nil},
    "transliteration" => %{"en" => nil, "ml" => nil},
    "translation" => %{"en" => nil, "ar" => nil, "ml" => nil},
    "audio" => nil,
    "references" => []
  }

  defp create(document, id \\ Awrad.UUIDv7.generate()) do
    %{
      "command_id" => Awrad.UUIDv7.generate(),
      "entity_type" => "custom_dhikr",
      "entity_id" => id,
      "op" => "put",
      "base_version" => 0,
      "document" => document
    }
  end

  defp insert_dhikrs(user_id, count, state) do
    now = DateTime.utc_now(:second)

    rows =
      for n <- 1..count do
        %{
          id: Awrad.UUIDv7.generate(),
          user_id: user_id,
          entity_type: "custom_dhikr",
          entity_id: Awrad.UUIDv7.generate(),
          version: 1,
          revision: n,
          state: state,
          document: if(state == "active", do: @dhikr),
          inserted_at: now,
          updated_at: now
        }
      end

    Repo.insert_all(Entity, rows)
  end

  test "an account has at most 1,000 active custom dhikrs; deleted ones don't count" do
    %{id: user_id} = user_fixture()
    insert_dhikrs(user_id, 999, "active")
    insert_dhikrs(user_id, 5, "deleted")

    %{receipts: [applied, rejected]} = Sync.apply_batch(user_id, [create(@dhikr), create(@dhikr)])

    assert %{"status" => "applied"} = applied

    assert %{"status" => "rejected", "code" => "custom_dhikr_limit_reached", "current" => nil} =
             rejected
  end

  test "a document over 64 KB of compact UTF-8 JSON is document_too_large" do
    %{id: user_id} = user_fixture()
    # 2-byte Arabic letters: 32,600 of them fit, with the rest of the document.
    fits = %{@dhikr | "arabic" => String.duplicate("س", 32_600)}
    too_large = %{@dhikr | "arabic" => String.duplicate("س", 33_000)}

    assert byte_size(Jason.encode!(fits)) <= 65_536
    assert byte_size(Jason.encode!(too_large)) > 65_536

    %{receipts: [first, second]} = Sync.apply_batch(user_id, [create(fits), create(too_large)])

    # Within 64 KB, but still over the 5,000 code points the schema allows.
    assert %{"code" => "document_invalid", "fields" => [%{"field" => "/document/arabic"}]} = first
    assert %{"code" => "document_too_large", "fields" => []} = second
  end

  test "receipts are kept 90 days" do
    %{id: user_id} = user_fixture()
    %{receipts: [_]} = Sync.apply_batch(user_id, [create(@dhikr)])
    [receipt] = Repo.all(Receipt)

    assert Sync.prune(DateTime.add(receipt.inserted_at, 90, :day)) == 0
    assert Sync.prune(DateTime.add(receipt.inserted_at, 90 * 86_400 + 1, :second)) == 1
  end

  test "the payload hash covers the payload, not the command ID" do
    command = create(@dhikr)
    changed = put_in(command, ["document", "title", "en"], "Glory")

    # Canonical JSON: members sorted by name, whatever the map's own order.
    assert Receipt.payload_hash(command) ==
             :crypto.hash(
               :sha256,
               ~s|{"base_version":0,"document":{"arabic":"سُبْحَانَ ٱللَّهِ","audio":null,| <>
                 ~s|"kind":"dhikr","references":[],"title":{"ar":null,"en":"Subhanallah","ml":null},| <>
                 ~s|"translation":{"ar":null,"en":null,"ml":null},"transliteration":{"en":null,"ml":null}},| <>
                 ~s|"entity_id":"#{command["entity_id"]}","entity_type":"custom_dhikr","op":"put"}|
             )

    assert Receipt.payload_hash(changed) != Receipt.payload_hash(command)

    assert Receipt.payload_hash(%{command | "command_id" => Awrad.UUIDv7.generate()}) ==
             Receipt.payload_hash(command)
  end
end
