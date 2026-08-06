defmodule AwradApi.ProgressSyncDocumentTest do
  use ExUnit.Case, async: true

  alias AwradApi.ProgressSync.Document

  @tag_id "11111111-1111-4111-8111-111111111111"
  @now "2026-07-24T10:00:00Z"

  test "user_tag trims, collapses whitespace, NFC-normalizes display, and case-folds uniqueness" do
    # "e\u0301" is e + combining acute; NFC form is "é"
    raw_name = "  Befor" <> "e\u0301" <> "   Sleep  "

    assert {:ok, document} =
             Document.validate(
               "user_tag",
               %{
                 "id" => @tag_id,
                 "name" => raw_name,
                 "normalized_name" => "beforé sleep",
                 "created_at" => @now,
                 "updated_at" => @now
               },
               @tag_id
             )

    assert document["name"] == "Beforé Sleep"
    assert document["normalized_name"] == "beforé sleep"
    assert document["id"] == @tag_id
  end

  test "user_tag rejects empty, oversized, and mismatched normalized names" do
    assert {:error, :invalid_entity_document} =
             Document.validate(
               "user_tag",
               tag_doc("   "),
               @tag_id
             )

    too_long = String.duplicate("a", 41)

    assert {:error, :invalid_entity_document} =
             Document.validate(
               "user_tag",
               tag_doc(too_long, "a" |> String.duplicate(41)),
               @tag_id
             )

    assert {:error, :invalid_entity_document} =
             Document.validate(
               "user_tag",
               tag_doc("Sleep", "SLEEP"),
               @tag_id
             )
  end

  test "user_tag preserves Arabic marks rather than stripping them for uniqueness" do
    marked = "سَلام"
    unmarked = "سلام"

    assert {:ok, marked_doc} =
             Document.validate("user_tag", tag_doc(marked, String.downcase(marked)), @tag_id)

    assert {:ok, unmarked_doc} =
             Document.validate(
               "user_tag",
               tag_doc(
                 unmarked,
                 String.downcase(unmarked),
                 "22222222-2222-4222-8222-222222222222"
               ),
               "22222222-2222-4222-8222-222222222222"
             )

    assert marked_doc["normalized_name"] != unmarked_doc["normalized_name"]
  end

  test "shared tag-normalization contract locks NFC display, full case fold, and Unicode whitespace" do
    contract_path =
      Path.expand(
        "../../../contracts/behavior-model/v1/fixtures/tag-normalization-contract.json",
        __DIR__
      )

    assert File.exists?(contract_path), "missing shared tag-normalization-contract.json"

    %{"version" => 1, "algorithm" => algorithm, "cases" => cases} =
      contract_path |> File.read!() |> Jason.decode!()

    assert algorithm["display"] == "trim_collapse_unicode_whitespace_then_nfc"
    assert algorithm["normalized"] == "unicode_default_casefold_then_nfc"
    assert algorithm["whitespace"] == "unicode_white_space_property"

    by_id = Map.new(cases, &{&1["id"], &1})

    for id <- [
          "eszett_ss_full_casefold",
          "dotted_capital_i_full_casefold",
          "nnbsp_and_figure_space_collapse"
        ] do
      assert Map.has_key?(by_id, id), "contract missing case #{id}"
    end

    eszett = by_id["eszett_ss_full_casefold"]
    assert {:ok, display_a, normalized_a} = Document.normalize_tag_name(eszett["input_a"])
    assert {:ok, display_b, normalized_b} = Document.normalize_tag_name(eszett["input_b"])
    assert display_a == eszett["expected_display_a"]
    assert display_b == eszett["expected_display_b"]
    assert normalized_a == eszett["expected_normalized"]
    assert normalized_b == eszett["expected_normalized"]

    dotted = by_id["dotted_capital_i_full_casefold"]
    assert {:ok, display, normalized} = Document.normalize_tag_name(dotted["input"])
    assert display == dotted["expected_display"]
    assert normalized == dotted["expected_normalized"]

    spaces = by_id["nnbsp_and_figure_space_collapse"]
    assert {:ok, display, normalized} = Document.normalize_tag_name(spaces["input"])
    assert display == spaces["expected_display"]
    assert normalized == spaces["expected_normalized"]
  end

  test "dhikr_tag_assignment requires tag and dhikr UUIDv4 identities" do
    assignment_id = "33333333-3333-4333-8333-333333333333"

    assert {:ok, document} =
             Document.validate(
               "dhikr_tag_assignment",
               %{
                 "id" => assignment_id,
                 "tag_id" => @tag_id,
                 "dhikr_id" => "44444444-4444-4444-8444-444444444444",
                 "created_at" => @now
               },
               assignment_id
             )

    assert document["tag_id"] == @tag_id

    assert {:error, :invalid_entity_document} =
             Document.validate(
               "dhikr_tag_assignment",
               %{
                 "id" => assignment_id,
                 "tag_id" => "not-a-uuid",
                 "dhikr_id" => "44444444-4444-4444-8444-444444444444",
                 "created_at" => @now
               },
               assignment_id
             )
  end

  defp tag_doc(name, normalized \\ nil, id \\ @tag_id) do
    fallback_normalized =
      case Document.normalize_tag_name(name) do
        {:ok, _display, expected} -> expected
        :error -> ""
      end

    %{
      "id" => id,
      "name" => name,
      "normalized_name" => normalized || fallback_normalized,
      "created_at" => @now,
      "updated_at" => @now
    }
  end
end
