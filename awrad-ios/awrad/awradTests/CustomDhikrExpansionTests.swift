import Foundation
import Testing
@testable import awrad

@MainActor
struct CustomDhikrExpansionTests {
    @Test func snapshotV6IncludesTagsAndAcceptsV5WithoutAudioBytes() throws {
        #expect(AwradSnapshot.currentSchemaVersion == 6)

        let tag = UserTag(
            id: UUID(),
            name: "Sleep",
            normalizedName: "sleep",
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 10)
        )
        let dhikrID = UUID()
        let assignment = DhikrTagAssignment(
            id: UUID(),
            tagID: tag.id,
            dhikrID: dhikrID,
            createdAt: Date(timeIntervalSince1970: 11)
        )
        let v6 = AwradSnapshot(
            schemaVersion: 6,
            dhikrs: [],
            goals: [],
            countEntries: [],
            wirds: [],
            wirdSessions: [],
            preferences: UserPreferences(),
            userTags: [tag],
            tagAssignments: [assignment]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(v6)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AwradSnapshot.self, from: encoded)
        #expect(decoded.userTags == [tag])
        #expect(decoded.tagAssignments == [assignment])
        #expect(!String(data: encoded, encoding: .utf8)!.contains("audioAssets"))
        #expect(!String(data: encoded, encoding: .utf8)!.contains("relativeFileName"))

        let v5JSON = """
        {"schemaVersion":5,"dhikrs":[],"goals":[],"countEntries":[],"wirds":[],"wirdSessions":[],"preferences":{}}
        """.data(using: .utf8)!
        let upgraded = try AwradSnapshot.decodeCompatible(from: v5JSON)
        #expect(upgraded.schemaVersion == 6)
        #expect(upgraded.userTags.isEmpty)
        #expect(upgraded.tagAssignments.isEmpty)
    }

    @Test func storeCreatesRenamesDeletesTagsAndCascadesAssignmentsOnly() async throws {
        let url = temporarySnapshotURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()

        let dhikr = try #require(store.createDhikr(
            title: "Custom",
            arabic: "ذكر",
            transliteration: "Dhikr",
            translation: "Remembrance",
            category: .general
        ))
        let tag = try #require(store.createUserTag(name: "  Before   Sleep  "))
        #expect(tag.name == "Before Sleep")
        #expect(tag.normalizedName == "before sleep")

        let assignment = try #require(store.assignTag(tag.id, to: dhikr.id))
        #expect(store.tagAssignments.contains(assignment))

        let renamed = try #require(store.renameUserTag(id: tag.id, name: "Before rest"))
        #expect(renamed.name == "Before rest")
        #expect(store.tagAssignments.contains { $0.id == assignment.id && $0.tagID == tag.id })

        #expect(store.deleteUserTag(tag.id))
        #expect(store.userTags.isEmpty)
        #expect(store.tagAssignments.isEmpty)
        #expect(store.dhikr(id: dhikr.id) != nil)
    }

    @Test func customTitleChangeEmitsSchedulingForLinkedGoals() async throws {
        let url = temporarySnapshotURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        let dhikr = try #require(store.createDhikr(
            title: "Old title",
            arabic: "ذكر",
            transliteration: "Old",
            translation: "Old",
            category: .general
        ))
        let goal = store.createGoal(dhikrID: dhikr.id, target: 10)
        let before = store.notificationSchedulingChanges.revision
        #expect(store.updateDhikr(
            id: dhikr.id,
            title: "New title",
            arabic: "ذكر",
            transliteration: "New",
            translation: "New",
            category: .general
        ) != nil)
        #expect(store.notificationSchedulingChanges.revision == before + 1)
        #expect(store.notificationSchedulingChanges.latest.goalIDs.contains(goal.id))
    }

    @Test func deleteCustomDhikrRemovesAssignmentsAndOwnedAudioMetadata() async throws {
        let url = temporarySnapshotURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let audioRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("owned-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: audioRoot) }

        let store = AwradStore(snapshotURL: url, ownedAudioStore: OwnedDhikrAudioStore(rootDirectory: audioRoot))
        await store.bootstrap()
        let dhikr = try #require(store.createDhikr(
            title: "Audio custom",
            arabic: "ذكر",
            transliteration: "Audio",
            translation: "Audio",
            category: .general
        ))
        let tag = try #require(store.createUserTag(name: "Family"))
        _ = try #require(store.assignTag(tag.id, to: dhikr.id))

        let source = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).wav")
        try Data(repeating: 3, count: 64).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        let staged = try store.ownedAudioStore.stageImport(
            from: source,
            suggestedExtension: "wav",
            inspector: .init(inspect: { _ in
                OwnedDhikrAudioInspection(
                    mimeType: "audio/wav",
                    durationMs: 100,
                    sha256: String(repeating: "1", count: 64)
                )
            })
        )
        #expect(store.attachOwnedAudio(staged, to: dhikr.id) != nil)
        #expect(store.audioAsset(for: dhikr.id) != nil)

        let removedGoalIDs = try #require(store.deleteCustomDhikr(dhikr.id))
        #expect(removedGoalIDs.isEmpty)
        #expect(store.dhikr(id: dhikr.id) == nil)
        #expect(store.tagAssignments.filter { $0.dhikrID == dhikr.id }.isEmpty)
        #expect(store.audioAsset(for: dhikr.id) == nil)
        #expect(store.userTags.contains(where: { $0.id == tag.id }))
    }

    @Test func deepLinksPreferUUIDAndFallBackToSlug() throws {
        let id = UUID()
        let uuidLink = try #require(AwradDeepLink(url: URL(string: "awrad://counting?dhikr=\(id.uuidString)")!))
        #expect(uuidLink == .counting(dhikrID: id, dhikrSlug: nil))

        let slugLink = try #require(AwradDeepLink(url: URL(string: "awrad://counting?dhikr=surah-ikhlas")!))
        #expect(slugLink == .counting(dhikrID: nil, dhikrSlug: "surah-ikhlas"))

        #expect(
            AwradDeepLink.counting(dhikrID: id, dhikrSlug: nil).url.absoluteString
                == "awrad://counting?dhikr=\(id.uuidString.lowercased())"
        )
    }

    @Test func appIntentEntitiesExposeCustomDhikrsFromProjection() {
        let customID = UUID()
        let entities = AwradDhikrQuery.entities(
            from: [
                Dhikr(
                    id: customID,
                    title: "My Custom",
                    arabic: "ذكر",
                    transliteration: "Custom",
                    translation: "Custom",
                    category: .general,
                    isCustom: true
                )
            ]
        )
        #expect(entities.map(\.id) == [customID.uuidString.lowercased()])
        #expect(entities.first?.title == "My Custom")
    }

    private func temporarySnapshotURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-custom-expansion-\(UUID().uuidString)")
            .appendingPathExtension("json")
    }
}
