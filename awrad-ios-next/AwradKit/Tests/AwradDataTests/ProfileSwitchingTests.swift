import AwradDomain
import AwradTesting
import Foundation
import Testing

@testable import AwradData

/// Local profiles on disk: each its own database, swapped on sign-in, never mixed, and nothing sent
/// while signed out (ADR-2026-10-28).
@Suite("local profiles")
struct ProfileSwitchingTests {
    @Test func signedOutEditsAreSavedWithoutAnyRequest() async throws {
        let harness = try await StoreHarness(signedIn: false)
        defer { harness.removeDirectory() }
        await harness.store.start()
        let id = try await harness.store.saveCustomDhikr(id: nil, document: Sample.dhikr("Tasbih"))
        _ = try await harness.store.saveCustomDhikr(id: id, document: Sample.dhikr("Tasbih, edited"))
        let tag = try await harness.store.createTag(named: "Morning")
        try await harness.store.setTags([tag.id], on: id)
        try await harness.store.renameTag(tag.id, to: "Mornings")
        try await harness.store.deleteCustomDhikr(id)
        await harness.store.syncNow()

        #expect(await harness.server.requestCount == 0)
        let state = await harness.store.state()
        #expect(state.registry.active?.isAnonymous == true)
        #expect(state.registry.active?.hasData == true)
        #expect(state.unsentCount == 0, "an anonymous profile queues nothing")
        #expect(await harness.store.content().tags.map(\.name) == ["Mornings"])
    }

    @Test func addToMyAccountQueuesAndSendsEverything() async throws {
        let harness = try await StoreHarness(signedIn: false)
        defer { harness.removeDirectory() }
        let id = try await harness.store.saveCustomDhikr(id: nil, document: Sample.dhikr("Tasbih"))
        let tag = try await harness.store.createTag(named: "Morning")
        try await harness.store.setTags([tag.id], on: id)
        #expect(
            await harness.store.prompt(for: .signIn(accountID: harness.accountID, email: StoreHarness.email))
                == .anonymousData)

        _ = try await harness.signIn(choice: .addToAccount)

        #expect(await harness.store.state().unsentCount == 0)
        let order = await harness.server.sentBatches.flatMap(\.self).map(\.entityType)
        #expect(order == ["user_tag", "custom_dhikr", "dhikr_personal"], "references exist before they're used")
        #expect(await harness.server.document(SyncEntityKey(.customDhikr, id)) != nil)
    }

    @Test func eraseStartsAFreshProfileAndDeletesTheOldOne() async throws {
        let harness = try await StoreHarness(signedIn: false)
        defer { harness.removeDirectory() }
        _ = try await harness.store.saveCustomDhikr(id: nil, document: Sample.dhikr("Tasbih"))
        let anonymous = await harness.store.state().registry.activeProfileID

        _ = try await harness.signIn(choice: .erase)

        let state = await harness.store.state()
        #expect(state.registry.activeProfileID != anonymous)
        #expect(state.registry.profiles.count == 1)
        #expect(await harness.store.content().customDhikrs.isEmpty)
        #expect(
            !FileManager.default.fileExists(atPath: harness.directory.appending(path: anonymous.description).path()))
    }

    @Test func signingOutKeepsTheProfileAndQueuesUntilTheSameAccountReturns() async throws {
        let harness = try await StoreHarness(signedIn: false)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        await harness.signOut()
        let id = try await harness.store.saveCustomDhikr(id: nil, document: Sample.dhikr("Offline"))
        await harness.store.syncNow()
        #expect(await harness.server.sentBatches.isEmpty)
        #expect(await harness.store.state().unsentCount == 1)

        _ = try await harness.signIn()

        #expect(
            await harness.store.prompt(for: .signIn(accountID: harness.accountID, email: StoreHarness.email)) == nil)
        #expect(await harness.store.state().unsentCount == 0)
        #expect(await harness.server.document(SyncEntityKey(.customDhikr, id)) != nil)
    }

    @Test func anotherAccountGetsItsOwnProfileAndTheFirstStaysIntact() async throws {
        let harness = try await StoreHarness(signedIn: false)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        await harness.signOut()
        let id = try await harness.store.saveCustomDhikr(id: nil, document: Sample.dhikr("Amina's"))
        let first = await harness.store.state().registry.activeProfileID

        // Bilal's server is a different account: the fake refuses it, so nothing of Amina's is sent.
        await harness.account.signOut()
        _ = try await harness.signIn(email: "bilal@example.com")

        var state = await harness.store.state()
        #expect(state.registry.activeProfileID != first)
        #expect(await harness.store.content().customDhikrs.isEmpty, "Bilal sees none of Amina's data")
        #expect(state.registry.profile(first)?.hasUnsent == true)
        #expect(await harness.server.sentBatches.isEmpty)

        await harness.account.signOut()
        _ = try await harness.signIn()

        state = await harness.store.state()
        #expect(state.registry.activeProfileID == first)
        #expect(await harness.store.content().customDhikr(id) != nil)
        #expect(await harness.server.document(SyncEntityKey(.customDhikr, id)) != nil, "Amina's queue is sent")
    }

    @Test func removingAProfileErasesItsFiles() async throws {
        let harness = try await StoreHarness(signedIn: false)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        let first = await harness.store.state().registry.activeProfileID
        await harness.signOut()
        _ = try await harness.store.saveCustomDhikr(id: nil, document: Sample.dhikr("Unsent"))
        #expect(await harness.store.prompt(for: .removeProfile(first)) == .unsentChanges)

        await harness.store.handle(.removeProfile(first), choice: .remove)

        let state = await harness.store.state()
        #expect(state.registry.profile(first) == nil)
        #expect(state.registry.active?.isAnonymous == true)
        #expect(await harness.store.content().customDhikrs.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: harness.directory.appending(path: first.description).path()))
    }

    @Test func theRegistryAndDataSurviveARelaunch() async throws {
        let harness = try await StoreHarness(signedIn: false)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        let id = try await harness.store.saveCustomDhikr(id: nil, document: Sample.dhikr("Kept"))

        let relaunched = try LocalProfileStore(directory: harness.directory, account: harness.account, server: nil)
        await relaunched.start()

        #expect(await relaunched.state().registry.active?.accountID == harness.accountID)
        #expect(await relaunched.content().customDhikr(id) != nil)
        #expect(await relaunched.state().unsentCount == 1)
    }

    @Test func aDeletedAccountOffersToRemoveItsProfile() async throws {
        let harness = try await StoreHarness(signedIn: false)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        let profile = await harness.store.state().registry.activeProfileID
        await harness.store.askAboutDeletedAccount(harness.accountID)
        #expect(await harness.store.state().pendingPrompt?.prompt == .accountDeleted)

        await harness.store.answerPendingPrompt(.remove)

        let state = await harness.store.state()
        #expect(state.pendingPrompt == nil)
        #expect(state.registry.profile(profile) == nil)
        #expect(state.registry.signedInAccountID == nil)
    }

    @Test func addToMyAccountMergesIntoTheAccountsExistingProfile() async throws {
        let harness = try await StoreHarness(signedIn: false)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        let accountProfile = await harness.store.state().registry.activeProfileID
        let morning = try await harness.store.createTag(named: "Morning")
        try await harness.store.setTags([morning.id], on: Sample.builtIn)
        await harness.sync()
        await harness.signOut()
        // Bilal's profile, removed while active, leaves a fresh anonymous profile active.
        _ = try await harness.signIn(email: "bilal@example.com")
        let bilal = await harness.store.state().registry.activeProfileID
        await harness.signOut()
        await harness.store.handle(.removeProfile(bilal), choice: nil)
        let anonymous = await harness.store.state().registry.activeProfileID
        let mine = try await harness.store.createTag(named: "MORNING")
        let travel = try await harness.store.createTag(named: "Travel")
        try await harness.store.setTags([travel.id, mine.id], on: Sample.builtIn)
        let dhikr = try await harness.store.saveCustomDhikr(id: nil, document: Sample.dhikr("Travel dua"))

        _ = try await harness.signIn(choice: .addToAccount)

        let state = await harness.store.state()
        #expect(state.registry.activeProfileID == accountProfile)
        #expect(state.registry.profile(anonymous) == nil)
        #expect(
            !FileManager.default.fileExists(atPath: harness.directory.appending(path: anonymous.description).path()))
        let content = await harness.store.content()
        #expect(content.tags.map(\.name).sorted() == ["Morning", "Travel"], "MORNING folds onto Morning")
        #expect(content.tags(on: Sample.builtIn).map(\.id) == [morning.id, travel.id])
        #expect(content.customDhikr(dhikr) != nil)
        #expect(await harness.server.document(SyncEntityKey(.customDhikr, dhikr)) != nil, "the merge is sent")
        #expect(state.unsentCount == 0)
    }

    @Test func keepingADeletedAccountsProfileDropsItsQueueAndNeverQueuesAgain() async throws {
        let harness = try await StoreHarness(signedIn: false)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        let profile = await harness.store.state().registry.activeProfileID
        await harness.signOut()
        _ = try await harness.store.saveCustomDhikr(id: nil, document: Sample.dhikr("Unsent"))
        #expect(await harness.store.state().unsentCount == 1)
        let requests = await harness.server.requestCount
        await harness.store.askAboutDeletedAccount(harness.accountID)

        await harness.store.answerPendingPrompt(.keep)

        var state = await harness.store.state()
        #expect(state.registry.activeProfileID == profile)
        #expect(state.registry.active?.accountDeleted == true)
        #expect(state.unsentCount == 0, "its commands can never be sent")
        _ = try await harness.store.saveCustomDhikr(id: nil, document: Sample.dhikr("Offline"))
        state = await harness.store.state()
        #expect(state.unsentCount == 0)
        #expect(state.registry.active?.hasUnsent == false)
        #expect(await harness.store.content().customDhikrs.count == 2)
        await harness.store.syncNow()
        #expect(await harness.server.requestCount == requests, "it never syncs again")
    }

    @Test func updatesFollowAProfileSwitch() async throws {
        let harness = try await StoreHarness(signedIn: false)
        defer { harness.removeDirectory() }
        _ = try await harness.store.saveCustomDhikr(id: nil, document: Sample.dhikr("Anonymous"))
        let stream: AsyncStream<PersonalContent> = harness.store.updates()
        var updates = stream.makeAsyncIterator()
        #expect(await updates.next()?.customDhikrs.count == 1)

        _ = try await harness.signIn(choice: .erase)

        var latest: PersonalContent?
        while let content = await updates.next() {
            latest = content
            if content.customDhikrs.isEmpty { break }
        }
        #expect(latest?.customDhikrs.isEmpty == true)
    }
}
