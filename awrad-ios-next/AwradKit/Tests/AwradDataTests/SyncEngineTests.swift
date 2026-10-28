import AwradDomain
import AwradTesting
import Foundation
import Testing

@testable import AwradData

/// The sync engine against a fake server: every receipt status, the merge rewrite, conflicts,
/// paging, the account checks. Each test signs in first, so the profile belongs to the account.
@Suite("sync engine")
struct SyncEngineTests {
    @Test func appliedEditsLeaveTheQueueAndReachTheServer() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        let id = try await harness.store.saveCustomDhikr(id: nil, document: Sample.dhikr("Tasbih"))
        let tag = try await harness.store.createTag(named: "Morning")
        try await harness.store.setTags([tag.id], on: id)
        #expect(await harness.store.state().unsentCount == 3)

        await harness.sync()

        #expect(await harness.store.state().unsentCount == 0)
        #expect(await harness.server.document(SyncEntityKey(.customDhikr, id)) == Sample.dhikr("Tasbih").json)
        let personal = await harness.server.document(SyncEntityKey(.dhikrPersonal, id))
        #expect(personal == .object(["tag_ids": .array([.string(tag.id.description)])]))
        // Every batch named the profile's account.
        #expect(await harness.server.sentBatches.count == 1)
        guard case .upToDate = await harness.store.state().syncStatus else {
            Issue.record("not up to date")
            return
        }
    }

    @Test func aLostResponseIsReplayedAsADuplicate() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        let id = try await harness.store.saveCustomDhikr(id: nil, document: Sample.dhikr("Tasbih"))
        await harness.server.loseNextResponse()
        await harness.sync()
        #expect(await harness.store.state().unsentCount == 1)

        await harness.sync()

        #expect(await harness.store.state().unsentCount == 0)
        let commands = await harness.server.sentBatches.flatMap(\.self).map(\.commandID)
        #expect(commands.count == 2 && Set(commands).count == 1, "the same command, sent twice")
        #expect(await harness.server.entities[SyncEntityKey(.customDhikr, id)]?.version == 1)
    }

    @Test func aStaleEditOpensAConflictAndKeepMineWins() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        let id = try await harness.store.saveCustomDhikr(id: nil, document: Sample.dhikr("Tasbih"))
        await harness.sync()
        let key = SyncEntityKey(.customDhikr, id)
        await harness.server.put(key, .customDhikr(Sample.dhikr("Theirs")))
        _ = try await harness.store.saveCustomDhikr(id: id, document: Sample.dhikr("Mine"))

        await harness.store.syncNow()

        let conflicts = await harness.store.content().conflicts
        #expect(conflicts.map(\.key) == [key])
        #expect(conflicts.first?.server.document == .customDhikr(Sample.dhikr("Theirs")))
        #expect(await harness.store.content().customDhikr(id)?.document == Sample.dhikr("Mine"))

        await harness.store.resolveConflict(key, choice: .keepMine)
        await harness.sync()

        #expect(await harness.store.content().conflicts.isEmpty)
        #expect(await harness.server.document(key) == Sample.dhikr("Mine").json)
    }

    @Test func useTheirsTakesTheServersCopy() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        let id = try await harness.store.saveCustomDhikr(id: nil, document: Sample.dhikr("Tasbih"))
        await harness.sync()
        let key = SyncEntityKey(.customDhikr, id)
        await harness.server.put(key, .customDhikr(Sample.dhikr("Theirs")))
        _ = try await harness.store.saveCustomDhikr(id: id, document: Sample.dhikr("Mine"))
        await harness.sync()

        await harness.store.resolveConflict(key, choice: .useTheirs)

        #expect(await harness.store.content().customDhikr(id)?.document == Sample.dhikr("Theirs"))
        #expect(await harness.store.state().unsentCount == 0)
    }

    @Test func aMergedTagIsRewrittenEverywhere() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        let survivor = AwradID.random()
        await harness.server.put(
            SyncEntityKey(.userTag, survivor), .userTag(UserTagDocument(name: "MORNING", normalizedName: "morning")))
        // Offline on this phone: the same tag, and its use, in one batch.
        let tag = try await harness.store.createTag(named: "Morning")
        try await harness.store.setTags([tag.id], on: Sample.builtIn)

        await harness.sync()

        let content = await harness.store.content()
        #expect(content.tags.map(\.id) == [survivor])
        #expect(content.tagsByDhikr[Sample.builtIn] == [survivor])
        let personal = await harness.server.document(SyncEntityKey(.dhikrPersonal, Sample.builtIn))
        #expect(personal == .object(["tag_ids": .array([.string(survivor.description)])]))
    }

    @Test func aRecordEditedToNameALaterTagIsSentAfterIt() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        let morning = try await harness.store.createTag(named: "Morning")
        try await harness.store.setTags([morning.id], on: Sample.builtIn)
        // Offline: a new tag, then the never-sent record edited to use it.
        let evening = try await harness.store.createTag(named: "Evening")
        try await harness.store.setTags([morning.id, evening.id], on: Sample.builtIn)

        await harness.sync()

        let order = await harness.server.sentBatches.flatMap(\.self).map(\.entityType)
        #expect(order == ["user_tag", "user_tag", "dhikr_personal"], "the record follows the tag it names")
        let content = await harness.store.content()
        #expect(content.notices.isEmpty, "no tag_not_found")
        #expect(content.tagsByDhikr[Sample.builtIn] == [morning.id, evening.id])
        let personal = await harness.server.document(SyncEntityKey(.dhikrPersonal, Sample.builtIn))
        #expect(
            personal
                == .object(["tag_ids": .array([.string(morning.id.description), .string(evening.id.description)])]))
        #expect(await harness.store.state().unsentCount == 0)
    }

    @Test func aGoneEntityIsRemoved() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        let id = try await harness.store.saveCustomDhikr(id: nil, document: Sample.dhikr("Tasbih"))
        await harness.sync()
        await harness.server.delete(SyncEntityKey(.customDhikr, id))
        _ = try await harness.store.saveCustomDhikr(id: id, document: Sample.dhikr("Edited"))

        await harness.store.syncNow()

        #expect(await harness.store.content().customDhikr(id) == nil)
        #expect(await harness.store.state().unsentCount == 0)
    }

    @Test func aRejectedChangeIsUndoneWithANotice() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        await harness.server.reject("custom_dhikr_limit_reached")
        let id = try await harness.store.saveCustomDhikr(id: nil, document: Sample.dhikr("Tasbih"))

        await harness.sync()

        let content = await harness.store.content()
        #expect(content.customDhikr(id) == nil)
        #expect(content.notices == [SyncNotice(code: .customDhikrLimitReached, key: SyncEntityKey(.customDhikr, id))])
        await harness.store.dismissNotice(content.notices[0])
        #expect(await harness.store.content().notices.isEmpty)
    }

    @Test func theFeedIsReadPageByPage() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        await harness.server.setPageSize(2)
        for index in 1...5 {
            await harness.server.put(
                SyncEntityKey(.customDhikr, .random()), .customDhikr(Sample.dhikr("Dhikr \(index)")))
        }

        _ = try await harness.signIn()

        #expect(await harness.store.content().customDhikrs.count == 5)
        #expect(await harness.server.feedRequests == [0, 2, 4])
        #expect(await harness.store.state().registry.active?.after == 5)
    }

    @Test func anAccountMismatchStopsWithoutWriting() async throws {
        let harness = try await StoreHarness(signedIn: true, serverAccount: .random())
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        _ = try await harness.store.saveCustomDhikr(id: nil, document: Sample.dhikr("Tasbih"))

        await harness.sync()

        #expect(await harness.store.state().syncStatus == .accountMismatch)
        #expect(await harness.server.entities.isEmpty)
        #expect(await harness.store.state().unsentCount == 1)
    }

    @Test func aFailedSyncWaitsToRetry() async throws {
        let harness = try await StoreHarness(signedIn: true)
        defer { harness.removeDirectory() }
        await harness.server.fail(.unavailable)
        _ = try await harness.signIn()

        guard case .waitingToRetry = await harness.store.state().syncStatus else {
            Issue.record("expected a retry, got \(await harness.store.state().syncStatus)")
            return
        }
    }
}
