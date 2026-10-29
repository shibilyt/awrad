import AwradDomain
import AwradTesting
import Foundation
import SwiftData
import Testing

@testable import AwradData

/// The SwiftData side of the change queue: the phone's fixtures run through `SwiftDataSyncState`
/// exactly as through the in-memory state, and an edit is saved with its command in one transaction.
@Suite("sync persistence")
struct SyncPersistenceTests {
    @Test(arguments: try SyncFixtures.outboxEnqueue())
    func outboxEnqueueOnSwiftData(_ fixture: FixtureCase<OutboxEnqueueGiven, OutboxShape>) throws {
        let context = ModelContext(try ProfileStorage.inMemoryContainer())
        var state = SwiftDataSyncState(context: context)
        try copy(fixture.given.state(), into: &state)
        SyncRules.enqueue(try fixture.given.edit.edit(), in: &state)
        try context.save()
        #expect(OutboxShape(outbox: state.outbox.map(CommandShape.init)) == fixture.expect, "\(fixture.id)")
    }

    @Test(arguments: try SyncFixtures.applyChanges())
    func applyChangesOnSwiftData(_ fixture: FixtureCase<ApplyChangesGiven, ApplyChangesExpect>) throws {
        let context = ModelContext(try ProfileStorage.inMemoryContainer())
        var state = SwiftDataSyncState(context: context)
        let given = try fixture.given.local.state()
        try copy(given, into: &state)
        let (notices, uploads) = try fixture.given.run(on: &state)
        try context.save()
        let result = ApplyChangesExpect(
            local: LocalShape(try snapshot(state, keys: Set(given.documents.keys).union(given.knownVersions.keys))),
            notices: notices, uploadsQueued: uploads)
        #expect(result == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }

    /// profile_switch's merge cases: the anonymous data merged into the account's SwiftData profile.
    @Test(arguments: try SyncFixtures.profileSwitch().filter { $0.given.mergeData != nil })
    func profileMergeOnSwiftData(_ fixture: FixtureCase<ProfileSwitchGiven, ProfileSwitchExpect>) throws {
        let data = try #require(fixture.given.mergeData)
        let context = ModelContext(try ProfileStorage.inMemoryContainer())
        var state = SwiftDataSyncState(context: context)
        try copy(data.account.state(), into: &state)
        SyncRules.merge(try data.anonymous.state(), into: &state)
        try context.save()
        let merged = try MergedDataShape(try snapshot(state, keys: []), given: data)
        #expect(merged == fixture.expect.mergedData, "\(fixture.id)")
    }

    @Test func anEditAndItsCommandAreSavedTogether() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "awrad-store-\(AwradID.random())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let files = ProfileFiles(root: directory)
        let profile = AwradID.random()
        let id = AwradID.random()
        let database = ProfileDatabase(modelContainer: try files.container(profile))
        try await database.save(.put(.customDhikr(Sample.dhikr("Tasbih")), id: id), queue: true)

        // A fresh container on the same file sees both, or neither.
        let reopened = ProfileDatabase(modelContainer: try files.container(profile))
        #expect(await reopened.document(SyncEntityKey(.customDhikr, id)) == .customDhikr(Sample.dhikr("Tasbih")))
        let outbox = await reopened.outbox()
        #expect(outbox.map(\.key) == [SyncEntityKey(.customDhikr, id)])
        #expect(outbox.first?.baseVersion == 0)
    }

    @Test func aRefusedEditSavesNothing() async throws {
        let database = ProfileDatabase(modelContainer: try ProfileStorage.inMemoryContainer())
        var invalid = Sample.dhikr("Tasbih")
        invalid.arabic = "  "
        await #expect(throws: PersonalLibraryError.invalidDhikr([SyncFieldError(field: "/arabic", code: "blank")])) {
            try await database.save(.put(.customDhikr(invalid), id: .random()), queue: true)
        }
        let tag = UserTagDocument(name: "Morning", normalizedName: "morning")
        try await database.save(.put(.userTag(tag), id: .random()), queue: true)
        await #expect(throws: PersonalLibraryError.tagNameTaken) {
            try await database.save(
                .put(.userTag(UserTagDocument(name: "MORNING", normalizedName: "morning")), id: .random()), queue: true)
        }
        #expect(await database.summary() == ProfileDatabaseSummary(hasData: true, unsentCount: 1, after: 0))
    }

    @Test func eachEditRecordsOnlyItsOwnCommand() async throws {
        let database = ProfileDatabase(modelContainer: try ProfileStorage.inMemoryContainer())
        let first = AwradID.random()
        let second = AwradID.random()
        try await database.save(.put(.customDhikr(Sample.dhikr("One")), id: first), queue: true)
        try await database.save(.put(.customDhikr(Sample.dhikr("Two")), id: second), queue: true)
        _ = try await database.nextBatch(limit: 1)
        try await database.save(.put(.customDhikr(Sample.dhikr("One again")), id: first), queue: true)
        try await database.save(.put(.customDhikr(Sample.dhikr("Two again")), id: second), queue: true)

        let outbox = await database.outbox()
        // The sent command is followed by a chained one; the unsent one is replaced in place.
        #expect(outbox.map(\.key.id) == [first, second, first])
        #expect(outbox.map(\.baseVersion) == [0, 0, 1])
        #expect(outbox.map(\.sent) == [true, false, false])
        #expect(outbox[1].document == .customDhikr(Sample.dhikr("Two again")))
    }

    // MARK: - Helpers

    private func copy(_ source: InMemorySyncState, into state: inout SwiftDataSyncState) throws {
        state.after = source.after
        for (key, document) in source.documents { state.setDocument(document, for: key) }
        for (key, version) in source.knownVersions { state.setKnownVersion(version, for: key) }
        for command in source.outbox { state.appendCommand(command) }
        for (key, conflict) in source.conflicts { state.setConflict(conflict, for: key) }
        try state.context.save()
    }

    private func snapshot(_ state: SwiftDataSyncState, keys: Set<SyncEntityKey>) throws -> InMemorySyncState {
        var memory = InMemorySyncState(after: state.after, outbox: state.outbox)
        let all = keys.union(state.allKeys())
        for key in all {
            if let document = state.document(key) {
                memory.setDocument(document, for: key)
                memory.setKnownVersion(state.knownVersion(key), for: key)
            }
        }
        for conflict in state.allConflicts() { memory.setConflict(conflict, for: conflict.key) }
        return memory
    }
}
