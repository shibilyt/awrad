defmodule AwradServer.ProgressSyncCategoryTest do
  use ExUnit.Case, async: true

  alias AwradServer.ProgressSync.Document

  @dhikr_id "3f56af85-a640-4d0d-a1bd-956118fc542f"

  test "custom dhikr accepts an ordered unique category list" do
    document = Map.put(custom_dhikr(), "categories", ["general", "morning", "after_salah"])

    assert {:ok, normalized} = Document.validate("custom_dhikr", document, @dhikr_id)
    assert normalized["category"] == "general"
    assert normalized["categories"] == ["general", "morning", "after_salah"]
  end

  test "legacy custom dhikr defaults categories to its primary category" do
    assert {:ok, normalized} = Document.validate("custom_dhikr", custom_dhikr(), @dhikr_id)
    assert normalized["categories"] == ["general"]
  end

  test "custom dhikr rejects empty duplicate mismatched or unknown categories" do
    invalid_lists = [
      [],
      ["general", "general"],
      ["morning", "general"],
      ["general", "unknown"]
    ]

    for categories <- invalid_lists do
      document = Map.put(custom_dhikr(), "categories", categories)

      assert {:error, :invalid_entity_document} =
               Document.validate("custom_dhikr", document, @dhikr_id)
    end
  end

  defp custom_dhikr do
    %{
      "id" => @dhikr_id,
      "catalog_key" => nil,
      "is_custom" => true,
      "title" => "Morning remembrance",
      "arabic" => "سبحان الله",
      "transliteration" => "Subhan Allah",
      "translation" => "Glory be to Allah",
      "audio_url" => nil,
      "audio_file_name" => nil,
      "category" => "general",
      "audio_count_per_play" => 1,
      "sort_order" => 0,
      "quran_ref" => nil,
      "benefits" => []
    }
  end
end
