import Foundation
import Testing
@testable import awrad

@MainActor
struct NotificationSchedulingChangeTests {
    @Test func successfulCountMutationEmitsExactlyOneAffectedGoalChange() async throws {
        let store = AwradStore(snapshotURL: temporarySnapshotURL())
        await store.bootstrap()
        let dhikr = try #require(store.dhikrs.first)
        let goal = store.createGoal(dhikrID: dhikr.id, target: 33)
        let before = store.notificationSchedulingChanges.revision

        _ = store.applyCount(goalID: goal.id)

        #expect(store.notificationSchedulingChanges.revision == before + 1)
        #expect(store.notificationSchedulingChanges.latest.reason == .countMutation)
        #expect(store.notificationSchedulingChanges.latest.goalIDs == [goal.id])
    }

    @Test func successfulGoalCreationEmitsExactlyOneAffectedGoalChange() async throws {
        let store = AwradStore(snapshotURL: temporarySnapshotURL())
        await store.bootstrap()
        let dhikr = try #require(store.dhikrs.first)
        let before = store.notificationSchedulingChanges.revision

        let created = store.createGoal(dhikrID: dhikr.id, target: 1)

        #expect(store.notificationSchedulingChanges.revision == before + 1)
        #expect(store.notificationSchedulingChanges.latest.reason == .goalMutation)
        #expect(store.notificationSchedulingChanges.latest.goalIDs == [created.id])
    }

    @Test func successfulWirdMutationEmitsCapacityRefresh() async {
        let store = AwradStore(snapshotURL: temporarySnapshotURL())
        await store.bootstrap()
        let before = store.notificationSchedulingChanges.revision
        let wird = Wird(slug: "capacity-test", localizedName: ["en": "Capacity"])

        _ = store.createWird(wird)

        #expect(store.notificationSchedulingChanges.revision == before + 1)
        #expect(store.notificationSchedulingChanges.latest.reason == .capacityRefresh)
    }

    @Test func prayerLeadPreferenceChangeEmitsExactlyOneSchedulingChange() async {
        let store = AwradStore(snapshotURL: temporarySnapshotURL())
        await store.bootstrap()
        let before = store.notificationSchedulingChanges.revision

        #expect(store.updatePreferences { $0.prayerSlotDefaultLeadMinutes = 45 })

        #expect(store.notificationSchedulingChanges.revision == before + 1)
        #expect(store.notificationSchedulingChanges.latest.reason == .preferenceMutation)
    }

    @Test func unchangedPrayerLeadAndUnrelatedPreferenceEmitNoSchedulingChange() async {
        let store = AwradStore(snapshotURL: temporarySnapshotURL())
        await store.bootstrap()
        let before = store.notificationSchedulingChanges.revision

        #expect(store.updatePreferences { $0.prayerSlotDefaultLeadMinutes = 30 })
        #expect(store.updatePreferences { $0.keepScreenOn = true })

        #expect(store.notificationSchedulingChanges.revision == before)
    }

    @Test func failedPrayerLeadPersistenceEmitsNoSchedulingChange() async {
        let store = AwradStore(
            snapshotURL: temporarySnapshotURL(),
            persistenceFailureInjector: { throw TestPersistenceError.failed }
        )
        await store.bootstrap()
        let before = store.notificationSchedulingChanges.revision

        #expect(!store.updatePreferences { $0.prayerSlotDefaultLeadMinutes = 45 })

        #expect(store.notificationSchedulingChanges.revision == before)
    }

    @Test func localResetEmitsSyncAllOnlyAfterCommit() async throws {
        let store = AwradStore(snapshotURL: temporarySnapshotURL())
        await store.bootstrap()
        let before = store.notificationSchedulingChanges.revision

        try store.resetLocalState()

        #expect(store.notificationSchedulingChanges.revision == before + 1)
        #expect(store.notificationSchedulingChanges.latest.reason == .syncAll)
    }

    @Test func deliveredCleanupPolicyIsIndependentForDisableAndSyncAll() {
        let disable = NotificationSchedulingChange.deliveredCleanupRequest(
            change: .init(goalIDs: [UUID()], reason: .preferenceMutation),
            urgencyRemindersEnabled: false
        )
        #expect(disable == UrgencyDeliveredCleanupRequest(
            goalIDs: [],
            removeAll: true,
            timing: .independentOfReconciliation
        ))

        let syncAll = NotificationSchedulingChange.deliveredCleanupRequest(
            change: .init(goalIDs: [], reason: .syncAll),
            urgencyRemindersEnabled: true
        )
        #expect(syncAll == UrgencyDeliveredCleanupRequest(
            goalIDs: [],
            removeAll: true,
            timing: .independentOfReconciliation
        ))
    }

    @Test func deliveredCleanupPolicyRequiresSuccessfulReconciliationForGoalMutation() {
        let goalID = UUID()
        let request = NotificationSchedulingChange.deliveredCleanupRequest(
            change: .init(goalIDs: [goalID], reason: .goalMutation),
            urgencyRemindersEnabled: true
        )
        #expect(request == UrgencyDeliveredCleanupRequest(
            goalIDs: [goalID],
            removeAll: false,
            timing: .afterSuccessfulReconciliation
        ))
    }

    private func temporarySnapshotURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("notification-scheduling-\(UUID().uuidString).json")
    }
}

private enum TestPersistenceError: Error {
    case failed
}
