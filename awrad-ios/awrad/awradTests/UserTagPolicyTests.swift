import Foundation
import Testing
@testable import awrad

struct UserTagPolicyTests {
    @Test func sharedNormalizationFixturesMatchDisplayAndCaseFold() throws {
        let data = try Data(contentsOf: behaviorFixtureURL)
        let document = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let cases = try #require(document["tag_normalization"] as? [[String: Any]])

        for fixture in cases {
            let id = try #require(fixture["id"] as? String)
            switch id {
            case "trim_collapse_casefold", "nfc_and_casefold", "dotted_i_full_casefold", "unicode_whitespace_collapse":
                let input = try #require(fixture["input"] as? String)
                let expectedDisplay = try #require(fixture["expected_display"] as? String)
                let expectedNormalized = try #require(fixture["expected_normalized"] as? String)
                let result = try #require(UserTagPolicy.normalize(input))
                #expect(result.displayName == expectedDisplay)
                #expect(result.normalizedName == expectedNormalized)
            case "arabic_marks_preserved", "sharp_s_full_casefold":
                let inputA = try #require(fixture["input_a"] as? String)
                let inputB = try #require(fixture["input_b"] as? String)
                let expectedSame = try #require(fixture["expected_same_normalized"] as? Bool)
                let normalizedA = try #require(UserTagPolicy.normalize(inputA)?.normalizedName)
                let normalizedB = try #require(UserTagPolicy.normalize(inputB)?.normalizedName)
                #expect((normalizedA == normalizedB) == expectedSame)
                if let expectedNormalized = fixture["expected_normalized"] as? String {
                    #expect(normalizedA == expectedNormalized)
                    #expect(normalizedB == expectedNormalized)
                }
            case "reject_empty_and_oversized":
                let nested = try #require(fixture["cases"] as? [[String: Any]])
                for entry in nested {
                    let input = try #require(entry["input"] as? String)
                    let accepted = try #require(entry["accepted"] as? Bool)
                    #expect((UserTagPolicy.normalize(input) != nil) == accepted)
                }
            default:
                Issue.record("Unhandled tag normalization fixture \(id)")
            }
        }
    }

    @Test func rejectsNamesExceedingUTF8ByteLimit() {
        // 40 graphemes of "あ" is under grapheme limit but can exceed 128 UTF-8 bytes.
        let oversized = String(repeating: "あ", count: 43)
        #expect(UserTagPolicy.normalize(oversized) == nil)
        #expect(UserTagPolicy.normalize("Sleep") != nil)
    }

    @Test func filterCombinesCustomScopeCategoryTagsAndSearchWithAND() {
        let sleep = UserTag(
            id: UUID(),
            name: "Sleep",
            normalizedName: "sleep",
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        let travel = UserTag(
            id: UUID(),
            name: "Travel",
            normalizedName: "travel",
            createdAt: Date(timeIntervalSince1970: 2),
            updatedAt: Date(timeIntervalSince1970: 2)
        )
        let family = UserTag(
            id: UUID(),
            name: "Family",
            normalizedName: "family",
            createdAt: Date(timeIntervalSince1970: 3),
            updatedAt: Date(timeIntervalSince1970: 3)
        )

        let matching = Dhikr(
            title: "Night protection",
            arabic: "ذكر",
            transliteration: "Night",
            translation: "Protection for the night",
            category: .protection,
            isCustom: true
        )
        let missingTag = Dhikr(
            title: "Night travel only",
            arabic: "ذكر",
            transliteration: "Night",
            translation: "Travel night",
            category: .protection,
            isCustom: true
        )
        let wrongCategory = Dhikr(
            title: "Night family travel",
            arabic: "ذكر",
            transliteration: "Night",
            translation: "Family travel night",
            category: .general,
            isCustom: true
        )
        let builtIn = Dhikr(
            title: "Night family travel",
            arabic: "ذكر",
            transliteration: "Night",
            translation: "Family travel night",
            category: .protection,
            isCustom: false
        )

        let assignments = [
            DhikrTagAssignment(id: UUID(), tagID: travel.id, dhikrID: matching.id, createdAt: Date()),
            DhikrTagAssignment(id: UUID(), tagID: family.id, dhikrID: matching.id, createdAt: Date()),
            DhikrTagAssignment(id: UUID(), tagID: travel.id, dhikrID: missingTag.id, createdAt: Date()),
            DhikrTagAssignment(id: UUID(), tagID: travel.id, dhikrID: wrongCategory.id, createdAt: Date()),
            DhikrTagAssignment(id: UUID(), tagID: family.id, dhikrID: wrongCategory.id, createdAt: Date()),
            DhikrTagAssignment(id: UUID(), tagID: travel.id, dhikrID: builtIn.id, createdAt: Date()),
            DhikrTagAssignment(id: UUID(), tagID: family.id, dhikrID: builtIn.id, createdAt: Date()),
            DhikrTagAssignment(id: UUID(), tagID: sleep.id, dhikrID: matching.id, createdAt: Date()),
        ]

        let results = LibraryCatalogPolicy.filtered(
            [matching, missingTag, wrongCategory, builtIn],
            query: "night",
            category: .protection,
            language: .english,
            collectionScope: .yourDhikrs,
            selectedTagIDs: [travel.id, family.id],
            tags: [sleep, travel, family],
            assignments: assignments
        )

        #expect(results.map(\.id) == [matching.id])
    }

    @Test func clearFiltersResetsCategoryTagsSearchAndCustomScope() {
        var filters = LibraryCatalogFilters(
            query: "night",
            category: .protection,
            collectionScope: .yourDhikrs,
            selectedTagIDs: [UUID()]
        )
        filters.clear()
        #expect(filters.query.isEmpty)
        #expect(filters.category == nil)
        #expect(filters.collectionScope == .all)
        #expect(filters.selectedTagIDs.isEmpty)
    }

    @Test func searchMatchesAssignedTagNames() {
        let tag = UserTag(
            id: UUID(),
            name: "Before Sleep",
            normalizedName: "before sleep",
            createdAt: Date(),
            updatedAt: Date()
        )
        let dhikr = Dhikr(
            title: "Protection",
            arabic: "ذكر",
            transliteration: "Himayah",
            translation: "Protection",
            category: .protection
        )
        let assignment = DhikrTagAssignment(
            id: UUID(),
            tagID: tag.id,
            dhikrID: dhikr.id,
            createdAt: Date()
        )

        let results = LibraryCatalogPolicy.filtered(
            [dhikr],
            query: "before sleep",
            category: nil,
            language: .english,
            tags: [tag],
            assignments: [assignment]
        )
        #expect(results.map(\.id) == [dhikr.id])
    }

    private var behaviorFixtureURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("contracts/behavior-model/v1/fixtures/behavior-cases.json")
    }
}
