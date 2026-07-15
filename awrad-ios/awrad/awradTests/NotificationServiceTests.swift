import Foundation
import Testing
import UserNotifications
@testable import awrad

@Suite(.serialized)
@MainActor
struct NotificationServiceTests {
    @Test func deniedAuthorizationIsObservableAndDoesNotRemoveExistingReminder() async {
        let existing = request(identifier: ReminderPlanner.dailyReminderIdentifier)
        let center = TestNotificationCenter(status: .denied, requests: [existing])
        let service = NotificationService(center: center)

        let result = await service.scheduleDailyReminder(hour: 8, minute: 15)

        #expect(result == .denied)
        #expect(center.requests[existing.identifier] != nil)
        #expect(center.removedIdentifiers.isEmpty)
    }

    @Test func authorizationFailureIsReturnedInsteadOfSwallowed() async {
        let center = TestNotificationCenter(status: .notDetermined)
        center.authorizationError = TestNotificationError.authorization
        let service = NotificationService(center: center)

        let result = await service.scheduleDailyRemembrance()

        guard case .failed(let message) = result else {
            Issue.record("Expected an observable authorization failure")
            return
        }
        #expect(!message.isEmpty)
        #expect(center.requests.isEmpty)
    }

    @Test func partialAddFailureCleansNewRequestsAndPreservesPreviousRequests() async {
        let stale = request(identifier: "awrad.wird.stale.keep")
        let center = TestNotificationCenter(status: .authorized, requests: [stale])
        center.failOnAddAttempt = 2
        let service = NotificationService(center: center)
        let wird = Wird(
            slug: "test",
            localizedName: ["en": "Test wird"],
            reminders: [
                WirdReminder(hour: 7, minute: 0),
                WirdReminder(hour: 18, minute: 0),
            ]
        )

        let result = await service.scheduleWirdReminders(for: wird)

        guard case .failed = result else {
            Issue.record("Expected a scheduling failure")
            return
        }
        #expect(center.requests[stale.identifier] != nil)
        #expect(center.requests.keys.filter { $0.hasPrefix(ReminderPlanner.wirdReminderIdentifierPrefix(for: wird.id)) }.isEmpty)
    }

    @Test func laterAddFailureRestoresAnEarlierSameIdentifierReplacement() async {
        let firstReminderID = UUID()
        let secondReminderID = UUID()
        let wird = Wird(
            slug: "replacement",
            localizedName: ["en": "Replacement"],
            reminders: [
                WirdReminder(id: firstReminderID, hour: 7, minute: 0),
                WirdReminder(id: secondReminderID, hour: 18, minute: 0),
            ]
        )
        let firstIdentifier = "\(ReminderPlanner.wirdReminderIdentifierPrefix(for: wird.id))\(firstReminderID.uuidString)"
        let originalContent = UNMutableNotificationContent()
        originalContent.title = "Original reminder"
        let original = UNNotificationRequest(identifier: firstIdentifier, content: originalContent, trigger: nil)
        let center = TestNotificationCenter(status: .authorized, requests: [original])
        center.failOnAddAttempt = 2
        let service = NotificationService(center: center)

        let result = await service.scheduleWirdReminders(for: wird)

        guard case .failed = result else {
            Issue.record("Expected the second add to fail")
            return
        }
        #expect(center.requests[firstIdentifier]?.content.title == "Original reminder")
        let secondIdentifier = "\(ReminderPlanner.wirdReminderIdentifierPrefix(for: wird.id))\(secondReminderID.uuidString)"
        #expect(center.requests[secondIdentifier] == nil)
    }

    @Test func reconciliationIncludesDailyRemembranceGoalsAndEveryWird() async {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 6))!
        let staleGoal = request(identifier: "\(ReminderPlanner.goalReminderIdentifierRoot)stale")
        let staleWird = request(identifier: "\(ReminderPlanner.wirdReminderIdentifierRoot)stale")
        let center = TestNotificationCenter(status: .authorized, requests: [staleGoal, staleWird])
        let service = NotificationService(center: center)
        let goal = goalWithReminder()
        let firstWird = wirdWithReminder(slug: "first", hour: 7)
        let secondWird = wirdWithReminder(slug: "second", hour: 19)

        let result = await service.refreshScheduledReminders(
            goalInputs: [
                GoalReminderScheduleInput(
                    goal: goal,
                    dhikrTitle: "Dhikr",
                    language: .english,
                    prayerTimes: []
                ),
            ],
            dailyReminder: (enabled: true, hour: 8, minute: 30, language: .english),
            dailyRemembrance: (enabled: true, language: .english),
            wirdInputs: [
                WirdReminderScheduleInput(wird: firstWird, language: .english, prayerTimes: nil),
                WirdReminderScheduleInput(wird: secondWird, language: .english, prayerTimes: nil),
            ],
            now: now,
            calendar: calendar
        )

        #expect(result.succeeded)
        #expect(center.requests[ReminderPlanner.dailyReminderIdentifier] != nil)
        #expect(center.requests[ReminderPlanner.dailyRemembranceIdentifier] != nil)
        #expect(center.requests.keys.contains { $0.hasPrefix(ReminderPlanner.goalReminderIdentifierPrefix(for: goal.id)) })
        #expect(center.requests.keys.contains { $0.hasPrefix(ReminderPlanner.wirdReminderIdentifierPrefix(for: firstWird.id)) })
        #expect(center.requests.keys.contains { $0.hasPrefix(ReminderPlanner.wirdReminderIdentifierPrefix(for: secondWird.id)) })
        #expect(center.requests[staleGoal.identifier] == nil)
        #expect(center.requests[staleWird.identifier] == nil)
    }

    @Test func emptyReconciliationClearsAllOwnedNotificationsWithoutRequestingPermission() async {
        let owned = [
            request(identifier: ReminderPlanner.dailyReminderIdentifier),
            request(identifier: ReminderPlanner.dailyRemembranceIdentifier),
            request(identifier: "\(ReminderPlanner.goalReminderIdentifierRoot)stale"),
            request(identifier: "\(ReminderPlanner.wirdReminderIdentifierRoot)stale"),
        ]
        let unrelated = request(identifier: "another-app-surface")
        let center = TestNotificationCenter(status: .denied, requests: owned + [unrelated])
        let service = NotificationService(center: center)

        let result = await service.refreshScheduledReminders(
            goalInputs: [],
            dailyReminder: (enabled: false, hour: 8, minute: 0, language: .english),
            dailyRemembrance: (enabled: false, language: .english),
            wirdInputs: []
        )

        #expect(result == .cleared)
        #expect(center.authorizationRequestCount == 0)
        #expect(center.requests.count == 1)
        #expect(center.requests[unrelated.identifier] != nil)
    }

    private func goalWithReminder() -> Goal {
        let goalID = UUID()
        let slot = GoalSlot(goalID: goalID, slotType: .anytime, targetCount: 33)
        let reminder = GoalReminder(
            goalID: goalID,
            reminderType: .fixedTime,
            hour: 8,
            minute: 0
        )
        return Goal(
            id: goalID,
            dhikrID: UUID(),
            recurrence: GoalRecurrence(frequency: .daily),
            slots: [slot],
            reminders: [reminder],
            startDate: "2026-07-15"
        )
    }

    private func wirdWithReminder(slug: String, hour: Int) -> Wird {
        Wird(
            slug: slug,
            localizedName: ["en": slug],
            reminders: [WirdReminder(hour: hour, minute: 0)]
        )
    }

    private func request(identifier: String) -> UNNotificationRequest {
        UNNotificationRequest(
            identifier: identifier,
            content: UNMutableNotificationContent(),
            trigger: nil
        )
    }
}

@MainActor
private final class TestNotificationCenter: AwradUserNotificationCenter {
    var status: UNAuthorizationStatus
    var authorizationResult = true
    var authorizationError: Error?
    var failOnAddAttempt: Int?
    private(set) var authorizationRequestCount = 0
    private(set) var addAttemptCount = 0
    private(set) var requests: [String: UNNotificationRequest]
    private(set) var removedIdentifiers: [String] = []

    init(status: UNAuthorizationStatus, requests: [UNNotificationRequest] = []) {
        self.status = status
        self.requests = Dictionary(uniqueKeysWithValues: requests.map { ($0.identifier, $0) })
    }

    func awradAuthorizationStatus() async -> UNAuthorizationStatus { status }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationRequestCount += 1
        if let authorizationError { throw authorizationError }
        status = authorizationResult ? .authorized : .denied
        return authorizationResult
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        Array(requests.values)
    }

    func add(_ request: UNNotificationRequest) async throws {
        addAttemptCount += 1
        if addAttemptCount == failOnAddAttempt { throw TestNotificationError.add }
        requests[request.identifier] = request
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
        for identifier in identifiers { requests.removeValue(forKey: identifier) }
    }
}

private enum TestNotificationError: LocalizedError {
    case authorization
    case add

    var errorDescription: String? {
        switch self {
        case .authorization: "Authorization failed"
        case .add: "Add failed"
        }
    }
}
