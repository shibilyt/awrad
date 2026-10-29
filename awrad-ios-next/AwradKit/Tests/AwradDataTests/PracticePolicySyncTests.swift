import AwradDomain
import AwradTesting
import Foundation
import Testing

@testable import AwradData

/// The practice policy in the profiles (slice 3d): saved per profile signed out, never counted as
/// data, seeded or taken at the first sign-in, queued like any edit, and merged by setting when two
/// devices edit before they sync.
@Suite("practice policy sync")
struct PracticePolicySyncTests {
    static let maghrib = PracticePolicy(
        dayReset: .maghrib, calculationMethod: .dubai, madhab: .shafi, weekStart: .monday, hijriCorrections: .none)

    private func policyKey(_ harness: StoreHarness) -> SyncEntityKey {
        SyncEntityKey(.practicePolicy, harness.accountID)
    }

    @Test func signedOutThePolicyIsSavedAndNothingIsSent() async throws {
        let harness = try await StoreHarness(signedIn: false)
        defer { harness.removeDirectory() }
        await harness.store.start()
        try await harness.store.savePolicy(Self.maghrib)
        await harness.store.syncNow()

        #expect(await harness.store.practiceSettings().policy == Self.maghrib)
        #expect(await harness.server.requestCount == 0)
        let state = await harness.store.state()
        #expect(state.registry.active?.hasData == false, "settings alone aren't data")
        #expect(state.unsentCount == 0)
        #expect(
            await harness.store.prompt(for: .signIn(accountID: harness.accountID, email: StoreHarness.email)) == nil,
            "a profile with only a chosen policy is adopted without asking")
    }

    @Test func aChosenPolicySeedsAnUnsetAccount() async throws {
        let harness = try await StoreHarness(signedIn: false)
        defer { harness.removeDirectory() }
        try await harness.store.savePolicy(Self.maghrib)

        _ = try await harness.signIn()

        #expect(await harness.server.document(policyKey(harness)) == Self.maghrib.json)
        let sent = await harness.server.sentBatches.flatMap(\.self).filter { $0.entityType == "practice_policy" }
        #expect(sent.map(\.baseVersion) == [0], "a create")
        #expect(await harness.store.practiceSettings().policy == Self.maghrib)
        #expect(await harness.store.state().unsentCount == 0)
    }

    @Test func theAccountsPolicyWinsWhateverTheAnswer() async throws {
        for choice in [ProfileChoice.addToAccount, .erase] {
            let harness = try await StoreHarness(signedIn: false)
            defer { harness.removeDirectory() }
            let account = PracticePolicy(
                dayReset: .midnight, calculationMethod: .muslimWorldLeague, madhab: .hanafi, weekStart: .sunday,
                hijriCorrections: .none)
            await harness.server.put(policyKey(harness), .practicePolicy(account))
            _ = try await harness.store.saveCustomDhikr(id: nil, document: Sample.dhikr("Tasbih"))
            try await harness.store.savePolicy(Self.maghrib)

            _ = try await harness.signIn(choice: choice)

            #expect(await harness.store.practiceSettings().policy == account, "\(choice)")
            let sent = await harness.server.sentBatches.flatMap(\.self).filter { $0.entityType == "practice_policy" }
            #expect(sent.isEmpty, "\(choice): nothing sent for the policy")
            #expect(await harness.server.document(policyKey(harness)) == account.json)
        }
    }

    @Test func untouchedDefaultsAreNeverUploaded() async throws {
        let harness = try await StoreHarness(signedIn: false)
        defer { harness.removeDirectory() }

        _ = try await harness.signIn()

        #expect(await harness.server.document(policyKey(harness)) == nil)
        #expect(await harness.store.practiceSettings().policy == .default)
    }

    @Test func eraseKeepsAChosenPolicyForAnUnsetAccount() async throws {
        let harness = try await StoreHarness(signedIn: false)
        defer { harness.removeDirectory() }
        _ = try await harness.store.saveCustomDhikr(id: nil, document: Sample.dhikr("Tasbih"))
        try await harness.store.savePolicy(Self.maghrib)

        _ = try await harness.signIn(choice: .erase)

        #expect(await harness.store.content().customDhikrs.isEmpty)
        #expect(await harness.store.practiceSettings().policy == Self.maghrib)
        #expect(await harness.server.document(policyKey(harness)) == Self.maghrib.json)
    }

    @Test func editsOnTwoDevicesMergeBySetting() async throws {
        let harness = try await StoreHarness(signedIn: false)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        try await harness.store.savePolicy(Self.maghrib)
        await harness.sync()
        #expect(await harness.server.document(policyKey(harness)) == Self.maghrib.json)

        // Another device changes the week start; this one, before syncing, the madhab.
        var other = Self.maghrib
        other.weekStart = .saturday
        await harness.server.put(policyKey(harness), .practicePolicy(other))
        var mine = Self.maghrib
        mine.madhab = .hanafi
        try await harness.store.savePolicy(mine)
        await harness.sync()

        var merged = Self.maghrib
        merged.weekStart = .saturday
        merged.madhab = .hanafi
        #expect(await harness.store.practiceSettings().policy == merged)
        #expect(await harness.server.document(policyKey(harness)) == merged.json)
        #expect(await harness.store.content().conflicts.isEmpty, "a policy never opens a conflict")
        #expect(await harness.store.state().unsentCount == 0)
    }

    @Test func droppedCorrectionsShowANoticeInPracticeSettingsOnly() async throws {
        let harness = try await StoreHarness(signedIn: false)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        try await harness.store.savePolicy(.default)
        await harness.sync()
        var theirs = PracticePolicy.default
        theirs.hijriCorrections = try HijriCorrections([HijriCorrection(year: 1448, month: 5, offsetDays: -1)])
        await harness.server.put(policyKey(harness), .practicePolicy(theirs))
        var mine = PracticePolicy.default
        mine.hijriCorrections = try HijriCorrections([HijriCorrection(year: 1448, month: 4, offsetDays: 1)])
        try await harness.store.savePolicy(mine)
        await harness.sync()

        let settings = await harness.store.practiceSettings()
        #expect(settings.correctionsReplaced)
        #expect(settings.policy.hijriCorrections == theirs.hijriCorrections)
        #expect(await harness.store.content().notices.isEmpty, "the Library never shows it")
        await harness.store.dismissCorrectionsReplaced()
        #expect(await harness.store.practiceSettings().correctionsReplaced == false)
    }

    @Test func eachProfileKeepsItsOwnPolicy() async throws {
        let harness = try await StoreHarness(signedIn: false)
        defer { harness.removeDirectory() }
        _ = try await harness.signIn()
        try await harness.store.savePolicy(Self.maghrib)
        await harness.signOut()
        let profile = await harness.store.state().registry.activeProfileID
        await harness.store.handle(.removeProfile(profile), choice: .remove)

        #expect(await harness.store.practiceSettings().policy == .default, "a fresh profile starts at the default")
    }
}

@Suite("device context")
struct DeviceContextStoreTests {
    @Test func theLocationRoundTripsAndClears() async {
        let suite = "awrad-device-\(AwradID.random())"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let store = UserDefaultsDeviceContextStore(suiteName: suite)
        #expect(await store.location() == nil)
        let location = DeviceLocation(latitude: 11.25, longitude: 75.78, name: "Kozhikode", source: .city, cityID: 1)
        await store.setLocation(location)
        #expect(await UserDefaultsDeviceContextStore(suiteName: suite).location() == location)
        await store.setLocation(nil)
        #expect(await store.location() == nil)
    }

    @Test func itsStoredAsTheContractsLocation() throws {
        let location = DeviceLocation(latitude: 1.5, longitude: 2.5, name: nil, source: .gps, cityID: nil)
        let json = try AwradJSON.decode(JSONEncoder().encode(StoredLocation(location)))
        #expect(
            json
                == .object([
                    "latitude": .double(1.5), "longitude": .double(2.5), "name": .null, "source": .string("gps"),
                    "city_id": .null,
                ]))
    }
}
