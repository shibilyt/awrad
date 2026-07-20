import Foundation
import SwiftData
import Testing
@testable import awrad

@MainActor
struct AwradStorePersistenceIntegrationTests {
    @Test func everyParityRouteRoundTripsForSceneRestoration() throws {
        let idA = UUID()
        let idB = UUID()
        let routes: [AppRoute] = [
            .settings, .login, .signup, .forgotPassword,
            .verifyEmail(token: "verify"), .resetPassword(token: "reset"), .sessions,
            .counting(goalID: idA, slotID: idB), .createGoal(dhikrID: idA),
            .goalDetail(goalID: idA), .editGoal(goalID: idA),
            .editGoalSchedule(goalID: idA), .editGoalReminders(goalID: idA),
            .createDhikr, .editDhikr(idA), .category(.quran), .dhikrDetail(idA),
            .quranDhikrReader(dhikrID: idA, goalID: idB, slotID: nil),
            .wirdList, .wirdDetail(idA), .wirdReader(wirdID: idA, partID: idB),
            .createWird, .editWird(idA),
        ]
        let data = try JSONEncoder().encode(routes)
        #expect(try JSONDecoder().decode([AppRoute].self, from: data) == routes)
    }

    @Test func migratedStoreCanMutateAndRelaunchWithoutRevalidatingTheOldChecksum() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-store-runtime-\(UUID().uuidString)", isDirectory: true)
        let snapshotURL = directory.appendingPathComponent("awrad-snapshot.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let legacy = AwradStore(snapshotURL: snapshotURL)
        await legacy.bootstrap()
        let dhikrID = try #require(legacy.dhikrs.first?.id)
        let goal = legacy.createGoal(dhikrID: dhikrID, target: 7)
        try legacy.exportBackupData().write(to: snapshotURL, options: .atomic)

        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
        let runtime = AwradPersistenceRuntime(
            container: try AwradPersistenceContainerFactory.makeInMemoryContainer(),
            defaults: defaults,
            legacySnapshotURL: snapshotURL
        )
        let migrated = AwradStore(snapshotURL: snapshotURL)
        await migrated.bootstrap(persistence: runtime)

        let slotID = try #require(migrated.goal(id: goal.id)?.activeSlots.first?.id)
        #expect(migrated.addCount(goalID: goal.id, slotID: slotID) == 1)
        #expect(migrated.persistenceRecovery == nil)

        let relaunched = AwradStore(snapshotURL: snapshotURL)
        await relaunched.bootstrap(persistence: runtime)
        #expect(relaunched.count(for: try #require(relaunched.goal(id: goal.id)), slotID: slotID) == 1)
        #expect(relaunched.persistenceRecovery == nil)
    }

    @Test func corruptLegacyDataNeverSeedsAndExposesOriginalForRecovery() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-store-corrupt-\(UUID().uuidString)", isDirectory: true)
        let snapshotURL = directory.appendingPathComponent("awrad-snapshot.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{".utf8).write(to: snapshotURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: directory) }

        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
        let runtime = AwradPersistenceRuntime(
            container: try AwradPersistenceContainerFactory.makeInMemoryContainer(),
            defaults: defaults,
            legacySnapshotURL: snapshotURL
        )
        let store = AwradStore(snapshotURL: snapshotURL)
        await store.bootstrap(persistence: runtime)

        #expect(store.isReady)
        #expect(store.dhikrs.isEmpty)
        #expect(store.goals.isEmpty)
        #expect(store.persistenceRecovery?.isUsingLegacyFallback == false)
        #expect(store.persistenceRecovery?.exportURL == snapshotURL)
        #expect(try runtime.repository.isEmpty())
    }

    @Test func localResetReseedsOfflineStateAndCannotQueueCloudDeletes() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-local-reset-\(UUID().uuidString)", isDirectory: true)
        let snapshotURL = directory.appendingPathComponent("awrad-snapshot.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
        let runtime = AwradPersistenceRuntime(
            container: try AwradPersistenceContainerFactory.makeInMemoryContainer(),
            defaults: defaults,
            legacySnapshotURL: snapshotURL
        )
        let store = AwradStore(snapshotURL: snapshotURL)
        await store.bootstrap(persistence: runtime)
        let dhikrID = try #require(store.dhikrs.first?.id)
        #expect(store.completeOnboarding(name: "Previous user"))
        _ = store.createGoal(dhikrID: dhikrID, target: 33)
        #expect(store.goals.count == 1)

        try runtime.repository.performProgressSyncTransaction { context in
            _ = try ProgressSyncLocalStore.bind(
                userID: UUID().uuidString.lowercased(),
                installationID: UUID().uuidString.lowercased(),
                in: context
            )
            context.insert(AwradSchemaV2.SyncOutboxRecord(
                commandID: UUID().uuidString.lowercased(),
                actorSequence: 1,
                type: "entity_delete",
                payloadData: Data("{}".utf8),
                entityType: "goal",
                entityID: UUID().uuidString.lowercased()
            ))
        }
        try Data("legacy".utf8).write(to: runtime.legacySnapshotURL)
        try Data("backup".utf8).write(to: runtime.legacyBackupURL)
        runtime.migrationStateStore.markComplete(checksum: "old")

        try store.resetLocalState()

        #expect(store.dhikrs.count == AwradSeedData.dhikrs.count)
        #expect(store.goals.isEmpty)
        #expect(store.countEntries.isEmpty)
        #expect(store.wirdSessions.isEmpty)
        #expect(!store.preferences.isOnboarded)
        #expect(store.preferences.userName.isEmpty)
        #expect(try SharedProgressSyncPersistence.state(in: runtime.repository.modelContext) == nil)
        #expect(try runtime.repository.modelContext.fetchCount(
            FetchDescriptor<AwradSchemaV2.SyncOutboxRecord>()
        ) == 0)
        #expect(runtime.migrationStateStore.checksum == nil)
        #expect(!FileManager.default.fileExists(atPath: runtime.legacySnapshotURL.path))
        #expect(!FileManager.default.fileExists(atPath: runtime.legacyBackupURL.path))

        let relaunched = AwradStore(snapshotURL: snapshotURL)
        await relaunched.bootstrap(persistence: runtime)
        #expect(relaunched.dhikrs.count == AwradSeedData.dhikrs.count)
        #expect(relaunched.goals.isEmpty)
        #expect(!relaunched.preferences.isOnboarded)
    }

    @Test func finalOnboardingStepCommitsPreferencesAndFirstGoalTogether() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-onboarding-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        let dhikrID = try #require(store.dhikrs.first?.id)

        let goal = store.completeOnboardingAndCreateFirstGoal(
            name: "  Awrad User  ",
            dhikrID: dhikrID,
            target: 33,
            reminderPresetKeys: ["morning"],
            reminders: [GoalReminder(reminderType: .fixedTime, hour: 8, minute: 0)]
        )

        #expect(goal != nil)
        #expect(store.preferences.isOnboarded)
        #expect(store.preferences.userName == "Awrad User")
        #expect(store.preferences.onboardingReminderPresetKeys == ["morning"])
        #expect(store.goals.count == 1)

        let relaunched = AwradStore(snapshotURL: url)
        await relaunched.bootstrap()
        #expect(relaunched.preferences.isOnboarded)
        #expect(relaunched.goals.map(\.id) == [goal?.id].compactMap { $0 })
    }

    @Test func effectiveDayRefreshDoesNotDependOnOpeningHome() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awrad-effective-day-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = AwradStore(snapshotURL: url)
        await store.bootstrap()
        store.updatePreferences {
            $0.dayReset = .maghrib
            $0.latitude = 21.4225
            $0.longitude = 39.8262
            $0.calculationMethod = .ummAlQura
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let lateEvening = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 23, minute: 30))
        )
        store.refreshEffectiveDate(now: lateEvening)

        #expect(store.todayKey == "2026-07-16")
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "AwradStorePersistenceIntegrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(suite, forKey: "suite")
        return defaults
    }

    private func defaultsSuite(_ defaults: UserDefaults) -> String {
        defaults.string(forKey: "suite")!
    }
}
