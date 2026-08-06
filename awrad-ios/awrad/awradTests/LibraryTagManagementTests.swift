import Foundation
import Testing
@testable import awrad

struct LibraryTagFilterControlsTests {
    @Test func filterSummaryListsSelectedTagsAndScope() {
        let travel = UserTag(
            id: UUID(),
            name: "Travel",
            normalizedName: "travel",
            createdAt: Date(),
            updatedAt: Date()
        )
        let family = UserTag(
            id: UUID(),
            name: "Family",
            normalizedName: "family",
            createdAt: Date(),
            updatedAt: Date()
        )
        let filters = LibraryCatalogFilters(
            query: "night",
            category: .protection,
            collectionScope: .yourDhikrs,
            selectedTagIDs: [travel.id, family.id]
        )

        let summary = LibraryFilterAccessibility.summary(
            filters: filters,
            tags: [travel, family]
        )

        #expect(summary.localizedCaseInsensitiveContains("Your Dhikrs"))
        #expect(summary.localizedCaseInsensitiveContains("Protection"))
        #expect(summary.localizedCaseInsensitiveContains("Travel"))
        #expect(summary.localizedCaseInsensitiveContains("Family"))
        #expect(summary.localizedCaseInsensitiveContains("night"))
    }

    @Test func togglingTagUsesANDSelectionSet() {
        var filters = LibraryCatalogFilters()
        let tagA = UUID()
        let tagB = UUID()

        LibraryTagFilterControls.toggle(tagA, in: &filters)
        #expect(filters.selectedTagIDs == [tagA])

        LibraryTagFilterControls.toggle(tagB, in: &filters)
        #expect(filters.selectedTagIDs == [tagA, tagB])

        LibraryTagFilterControls.toggle(tagA, in: &filters)
        #expect(filters.selectedTagIDs == [tagB])
    }

    @Test func clearFiltersClearsTagsWithOtherDimensions() {
        var filters = LibraryCatalogFilters(
            query: "night",
            category: .protection,
            collectionScope: .yourDhikrs,
            selectedTagIDs: [UUID()]
        )
        filters.clear()
        #expect(filters.selectedTagIDs.isEmpty)
        #expect(filters.collectionScope == .all)
        #expect(filters.category == nil)
        #expect(filters.query.isEmpty)
    }
}

@MainActor
struct ManageTagsWorkflowTests {
    @Test func assignRemoveRenameDeleteFromBundledAndCustomTargets() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("manage-tags-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        let bundled = try #require(store.dhikrs.first { !$0.isCustom })
        let custom = try #require(store.createDhikr(
            title: "Custom bedtime",
            arabic: "ذكر",
            transliteration: "Custom",
            translation: "Custom",
            category: .protection
        ))

        let tag = try #require(store.createUserTag(name: "Sleep"))
        #expect(store.assignTag(tag.id, to: bundled.id) != nil)
        #expect(store.assignTag(tag.id, to: custom.id) != nil)
        #expect(store.tagAssignments.filter { $0.tagID == tag.id }.count == 2)

        #expect(store.renameUserTag(id: tag.id, name: "Before sleep")?.name == "Before sleep")
        #expect(store.unassignTag(tag.id, from: bundled.id))
        #expect(store.tagAssignments.contains { $0.tagID == tag.id && $0.dhikrID == custom.id })
        #expect(!store.tagAssignments.contains { $0.dhikrID == bundled.id })

        #expect(store.deleteUserTag(tag.id))
        #expect(store.userTags.isEmpty)
        #expect(store.tagAssignments.isEmpty)
        #expect(store.dhikr(id: bundled.id) != nil)
        #expect(store.dhikr(id: custom.id) != nil)
    }
}

struct AwradIntentDhikrProjectionTests {
    @Test func liveQueryPrefersAppGroupProjectionCustomsWithSeedFallback() throws {
        let customID = UUID()
        let projection = AwradIntentDhikrProjection(
            entries: [
                .init(
                    id: customID.uuidString.lowercased(),
                    title: "My Custom",
                    subtitle: "General",
                    isCustom: true
                )
            ]
        )

        let withProjection = AwradIntentDhikrProjection.resolvedEntities(
            projection: projection,
            seedFallback: [
                Dhikr(
                    title: "Surah Ikhlas",
                    arabic: "قُلْ هُوَ ٱللَّهُ أَحَدٌ",
                    transliteration: "Qul huwa",
                    translation: "Say He is Allah",
                    category: .quran
                )
            ]
        )
        #expect(withProjection.contains { $0.id == customID.uuidString.lowercased() && $0.title == "My Custom" })
        #expect(withProjection.contains { $0.id == "surah-ikhlas" })

        let fallbackOnly = AwradIntentDhikrProjection.resolvedEntities(
            projection: nil,
            seedFallback: [
                Dhikr(
                    title: "Surah Ikhlas",
                    arabic: "قُلْ هُوَ ٱللَّهُ أَحَدٌ",
                    transliteration: "Qul huwa",
                    translation: "Say He is Allah",
                    category: .quran
                )
            ]
        )
        #expect(fallbackOnly.map(\.id) == ["surah-ikhlas"])
        #expect(!fallbackOnly.contains { $0.id == customID.uuidString.lowercased() })
    }

    @Test func projectionRoundTripsThroughAppGroupDefaults() throws {
        let suite = "AwradIntentDhikrProjectionTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let customID = UUID()
        let projection = AwradIntentDhikrProjection.make(
            from: [
                Dhikr(
                    id: customID,
                    title: "Night Wird",
                    arabic: "ذكر",
                    transliteration: "Night",
                    translation: "Night",
                    category: .evening,
                    isCustom: true
                ),
                Dhikr(
                    title: "Surah Ikhlas",
                    arabic: "قُلْ",
                    transliteration: "Ikhlas",
                    translation: "Ikhlas",
                    category: .quran,
                    isCustom: false
                )
            ]
        )
        try projection.save(to: defaults)
        let loaded = try #require(AwradIntentDhikrProjection.load(from: defaults))
        #expect(loaded.entries.contains { $0.id == customID.uuidString.lowercased() && $0.isCustom })
        #expect(loaded.entries.contains { $0.id == "surah-ikhlas" && !$0.isCustom })
    }
}
