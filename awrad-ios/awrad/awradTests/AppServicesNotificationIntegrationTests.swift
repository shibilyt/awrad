import Foundation
import Testing
import UserNotifications
@testable import awrad

@Suite(.serialized)
@MainActor
struct AppServicesNotificationIntegrationTests {
    @Test func configuredRefreshSettlesBeforeUrgencyReconciliation() async {
        let events = NotificationIntegrationEvents()
        let configured = IntegrationConfiguredCenter(events: events, status: .authorized)
        let urgency = IntegrationUrgencyCenter(events: events, status: .authorized)
        let services = AppServices(
            notifications: NotificationService(center: configured),
            urgencyReconciler: UrgencyNotificationReconciler(
                center: urgency,
                ledger: InMemoryUrgencyDeliveredLedger()
            )
        )
        let store = AwradStore(snapshotURL: temporarySnapshotURL())
        await store.bootstrap()

        _ = await services.refreshNotifications(
            store: store,
            change: .init(goalIDs: [], reason: .syncAll)
        )

        let configuredCompletion = try! #require(events.values.lastIndex(of: "configured.pending"))
        let urgencyStart = try! #require(events.values.firstIndex(of: "urgency.authorization"))
        #expect(configuredCompletion < urgencyStart)
    }

    @Test func configuredFailureStillCleansDeliveredAfterSuccessfulUrgencyReconciliation() async {
        let events = NotificationIntegrationEvents()
        let configured = IntegrationConfiguredCenter(
            events: events,
            status: .authorized,
            addError: IntegrationError.configuredAdd
        )
        let urgency = IntegrationUrgencyCenter(events: events, status: .authorized)
        let services = AppServices(
            notifications: NotificationService(center: configured),
            urgencyReconciler: UrgencyNotificationReconciler(
                center: urgency,
                ledger: InMemoryUrgencyDeliveredLedger()
            )
        )
        let store = AwradStore(snapshotURL: temporarySnapshotURL())
        await store.bootstrap()
        store.updatePreferences { $0.dailyReminderEnabled = true }

        let result = await services.refreshNotifications(
            store: store,
            change: .init(goalIDs: [UUID()], reason: .goalMutation)
        )

        guard case .failed(let message) = result else {
            Issue.record("Configured scheduling failure must remain observable")
            return
        }
        #expect(message.contains("Configured reminders"))
        #expect(urgency.removeDeliveredCallCount == 1)
    }

    @Test func disableWithDeniedAuthorizationRemovesDeliveredUrgencyAndKeepsLedgerAndConfigured() async throws {
        let urgencyIdentity = NotificationNudgeIdentity(
            NotificationNudgeCandidateKey(
                goalID: UUID(),
                scope: "disable-denied",
                slotID: nil,
                kind: .deadlineWarning
            )
        ).canonicalKey
        let configuredIdentifier = ReminderPlanner.dailyReminderIdentifier
        let ledger = InMemoryUrgencyDeliveredLedger()
        try ledger.save([
            UrgencyDeliveredStage(
                identity: urgencyIdentity,
                deliveredAtMillis: 1,
                expiryMillis: 2
            )
        ])
        let urgency = IntegrationUrgencyCenter(
            events: NotificationIntegrationEvents(),
            status: .denied,
            delivered: [
                DeliveredUserNotification(
                    request: UNNotificationRequest(
                        identifier: urgencyIdentity,
                        content: UNMutableNotificationContent(),
                        trigger: nil
                    ),
                    date: Date()
                ),
                DeliveredUserNotification(
                    request: UNNotificationRequest(
                        identifier: configuredIdentifier,
                        content: UNMutableNotificationContent(),
                        trigger: nil
                    ),
                    date: Date()
                )
            ]
        )
        let services = AppServices(
            notifications: NotificationService(
                center: IntegrationConfiguredCenter(
                    events: NotificationIntegrationEvents(),
                    status: .denied
                )
            ),
            urgencyReconciler: UrgencyNotificationReconciler(center: urgency, ledger: ledger)
        )
        let store = AwradStore(snapshotURL: temporarySnapshotURL())
        await store.bootstrap()
        store.updatePreferences { $0.urgencyRemindersEnabled = false }

        let result = await services.refreshNotifications(
            store: store,
            change: .init(goalIDs: Set(store.goals.map(\.id)), reason: .preferenceMutation)
        )

        #expect(result == .denied || result.succeeded)
        #expect(urgency.removedDeliveredIdentifiers == [urgencyIdentity])
        #expect(urgency.delivered.map(\.request.identifier).sorted() == [configuredIdentifier])
        #expect(try ledger.load().map(\.identity) == [urgencyIdentity])
    }

    @Test func disableWithReconcilerFailureStillAttemptsCleanupAndReportsBoth() async {
        let urgency = IntegrationUrgencyCenter(
            events: NotificationIntegrationEvents(),
            status: .authorized,
            authorizationError: IntegrationError.urgencyAuthorization,
            deliveredError: IntegrationError.deliveredLookup
        )
        let services = AppServices(
            notifications: NotificationService(
                center: IntegrationConfiguredCenter(
                    events: NotificationIntegrationEvents(),
                    status: .authorized
                )
            ),
            urgencyReconciler: UrgencyNotificationReconciler(
                center: urgency,
                ledger: InMemoryUrgencyDeliveredLedger()
            )
        )
        let store = AwradStore(snapshotURL: temporarySnapshotURL())
        await store.bootstrap()
        store.updatePreferences { $0.urgencyRemindersEnabled = false }

        let result = await services.refreshNotifications(
            store: store,
            change: .init(goalIDs: Set(store.goals.map(\.id)), reason: .preferenceMutation)
        )

        guard case .failed(let message) = result else {
            Issue.record("Combined failure must remain observable")
            return
        }
        #expect(urgency.deliveredLookupCount >= 1)
        #expect(message.contains("Urgency reconciliation"))
        #expect(message.contains("Urgency delivered cleanup"))
    }

    @Test func syncAllWithDeniedAuthorizationRemovesDeliveredUrgencyAndKeepsLedgerAndConfigured() async throws {
        let urgencyIdentity = NotificationNudgeIdentity(
            NotificationNudgeCandidateKey(
                goalID: UUID(),
                scope: "syncall-denied",
                slotID: nil,
                kind: .deadlineWarning
            )
        ).canonicalKey
        let configuredIdentifier = ReminderPlanner.dailyReminderIdentifier
        let ledger = InMemoryUrgencyDeliveredLedger()
        try ledger.save([
            UrgencyDeliveredStage(
                identity: urgencyIdentity,
                deliveredAtMillis: 1,
                expiryMillis: 2
            )
        ])
        let urgency = IntegrationUrgencyCenter(
            events: NotificationIntegrationEvents(),
            status: .denied,
            delivered: [
                DeliveredUserNotification(
                    request: UNNotificationRequest(
                        identifier: urgencyIdentity,
                        content: UNMutableNotificationContent(),
                        trigger: nil
                    ),
                    date: Date()
                ),
                DeliveredUserNotification(
                    request: UNNotificationRequest(
                        identifier: configuredIdentifier,
                        content: UNMutableNotificationContent(),
                        trigger: nil
                    ),
                    date: Date()
                )
            ]
        )
        let services = AppServices(
            notifications: NotificationService(
                center: IntegrationConfiguredCenter(
                    events: NotificationIntegrationEvents(),
                    status: .denied
                )
            ),
            urgencyReconciler: UrgencyNotificationReconciler(center: urgency, ledger: ledger)
        )
        let store = AwradStore(snapshotURL: temporarySnapshotURL())
        await store.bootstrap()

        _ = await services.refreshNotifications(
            store: store,
            change: .init(goalIDs: [], reason: .syncAll)
        )

        #expect(urgency.removedDeliveredIdentifiers == [urgencyIdentity])
        #expect(urgency.delivered.map(\.request.identifier).sorted() == [configuredIdentifier])
        #expect(try ledger.load().map(\.identity) == [urgencyIdentity])
    }

    @Test func syncAllWithReconcilerFailureStillAttemptsCleanupAndReportsBoth() async {
        let urgency = IntegrationUrgencyCenter(
            events: NotificationIntegrationEvents(),
            status: .authorized,
            authorizationError: IntegrationError.urgencyAuthorization,
            deliveredError: IntegrationError.deliveredLookup
        )
        let services = AppServices(
            notifications: NotificationService(
                center: IntegrationConfiguredCenter(
                    events: NotificationIntegrationEvents(),
                    status: .authorized
                )
            ),
            urgencyReconciler: UrgencyNotificationReconciler(
                center: urgency,
                ledger: InMemoryUrgencyDeliveredLedger()
            )
        )
        let store = AwradStore(snapshotURL: temporarySnapshotURL())
        await store.bootstrap()

        let result = await services.refreshNotifications(
            store: store,
            change: .init(goalIDs: [], reason: .syncAll)
        )

        guard case .failed(let message) = result else {
            Issue.record("Combined failure must remain observable")
            return
        }
        #expect(urgency.deliveredLookupCount >= 1)
        #expect(message.contains("Urgency reconciliation"))
        #expect(message.contains("Urgency delivered cleanup"))
    }

    @Test func ordinaryGoalMutationWithUrgencyFailureDoesNotCleanupDelivered() async {
        let urgencyIdentity = NotificationNudgeIdentity(
            NotificationNudgeCandidateKey(
                goalID: UUID(),
                scope: "goal-fail",
                slotID: nil,
                kind: .deadlineWarning
            )
        ).canonicalKey
        let urgency = IntegrationUrgencyCenter(
            events: NotificationIntegrationEvents(),
            status: .denied,
            delivered: [
                DeliveredUserNotification(
                    request: UNNotificationRequest(
                        identifier: urgencyIdentity,
                        content: UNMutableNotificationContent(),
                        trigger: nil
                    ),
                    date: Date()
                )
            ]
        )
        let services = AppServices(
            notifications: NotificationService(
                center: IntegrationConfiguredCenter(
                    events: NotificationIntegrationEvents(),
                    status: .authorized
                )
            ),
            urgencyReconciler: UrgencyNotificationReconciler(
                center: urgency,
                ledger: InMemoryUrgencyDeliveredLedger()
            )
        )
        let store = AwradStore(snapshotURL: temporarySnapshotURL())
        await store.bootstrap()
        store.updatePreferences { $0.urgencyRemindersEnabled = true }

        _ = await services.refreshNotifications(
            store: store,
            change: .init(goalIDs: [UUID()], reason: .goalMutation)
        )

        #expect(urgency.removeDeliveredCallCount == 0)
        #expect(urgency.delivered.map(\.request.identifier) == [urgencyIdentity])
    }

    @Test func cleanupFailureIsReportedAlongsideSuccessfulConfiguredRefresh() async {
        let urgency = IntegrationUrgencyCenter(
            events: NotificationIntegrationEvents(),
            status: .denied,
            deliveredError: IntegrationError.deliveredLookup
        )
        let services = AppServices(
            notifications: NotificationService(
                center: IntegrationConfiguredCenter(
                    events: NotificationIntegrationEvents(),
                    status: .authorized
                )
            ),
            urgencyReconciler: UrgencyNotificationReconciler(
                center: urgency,
                ledger: InMemoryUrgencyDeliveredLedger()
            )
        )
        let store = AwradStore(snapshotURL: temporarySnapshotURL())
        await store.bootstrap()
        store.updatePreferences { $0.urgencyRemindersEnabled = false }

        let result = await services.refreshNotifications(
            store: store,
            change: .init(goalIDs: Set(store.goals.map(\.id)), reason: .preferenceMutation)
        )

        guard case .failed(let message) = result else {
            Issue.record("Cleanup failure must remain observable")
            return
        }
        #expect(message.contains("Urgency delivered cleanup"))
    }

    private func temporarySnapshotURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("app-services-notifications-\(UUID().uuidString).json")
    }
}

@MainActor
private final class NotificationIntegrationEvents {
    var values: [String] = []
}

@MainActor
private final class IntegrationConfiguredCenter: AwradUserNotificationCenter {
    let events: NotificationIntegrationEvents
    let status: UNAuthorizationStatus
    let addError: Error?

    init(
        events: NotificationIntegrationEvents,
        status: UNAuthorizationStatus,
        addError: Error? = nil
    ) {
        self.events = events
        self.status = status
        self.addError = addError
    }

    func awradAuthorizationStatus() async -> UNAuthorizationStatus {
        events.values.append("configured.authorization")
        return status
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { false }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        events.values.append("configured.pending")
        return []
    }

    func add(_ request: UNNotificationRequest) async throws {
        if let addError { throw addError }
    }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {}
}

private enum IntegrationError: Error, LocalizedError {
    case configuredAdd
    case urgencyAuthorization
    case deliveredLookup

    var errorDescription: String? {
        switch self {
        case .configuredAdd: "configured add failed"
        case .urgencyAuthorization: "urgency authorization failed"
        case .deliveredLookup: "delivered lookup failed"
        }
    }
}

@MainActor
private final class IntegrationUrgencyCenter: UrgencyNotificationCenter {
    let events: NotificationIntegrationEvents
    let status: UNAuthorizationStatus
    let authorizationError: Error?
    let deliveredError: Error?
    private(set) var delivered: [DeliveredUserNotification]
    private(set) var removeDeliveredCallCount = 0
    private(set) var removedDeliveredIdentifiers: [String] = []
    private(set) var deliveredLookupCount = 0

    init(
        events: NotificationIntegrationEvents,
        status: UNAuthorizationStatus,
        delivered: [DeliveredUserNotification] = [],
        authorizationError: Error? = nil,
        deliveredError: Error? = nil
    ) {
        self.events = events
        self.status = status
        self.delivered = delivered
        self.authorizationError = authorizationError
        self.deliveredError = deliveredError
    }

    func authorizationStatus() async throws -> UNAuthorizationStatus {
        events.values.append("urgency.authorization")
        if let authorizationError { throw authorizationError }
        return status
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { false }
    func pendingRequests() async throws -> [UNNotificationRequest] { [] }

    func deliveredNotifications() async throws -> [DeliveredUserNotification] {
        deliveredLookupCount += 1
        if let deliveredError { throw deliveredError }
        return delivered
    }

    func add(_ request: UNNotificationRequest) async throws {}
    func removePending(withIdentifiers identifiers: [String]) {}

    func removeDelivered(withIdentifiers identifiers: [String]) {
        removeDeliveredCallCount += 1
        removedDeliveredIdentifiers.append(contentsOf: identifiers)
        let removed = Set(identifiers)
        delivered.removeAll { removed.contains($0.request.identifier) }
    }
}
