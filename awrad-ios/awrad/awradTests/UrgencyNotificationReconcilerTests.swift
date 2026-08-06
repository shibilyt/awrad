import Foundation
import Testing
import UserNotifications
@testable import awrad

@MainActor
struct UrgencyNotificationReconcilerTests {
    @Test func notDeterminedDoesNotPromptOrSchedule() async throws {
        let center = UrgencyTestNotificationCenter(status: .notDetermined)
        let reconciler = UrgencyNotificationReconciler(
            center: center,
            ledger: InMemoryUrgencyDeliveredLedger()
        )

        let result = await reconciler.reconcile(
            desired: [planned(trigger: Date().addingTimeInterval(120))],
            now: Date()
        )

        #expect(result == .authorizationNotDetermined)
        #expect(center.added.isEmpty)
        #expect(center.requestAuthorizationCount == 0)
    }

    @Test func deniedRemovesOnlyEngineOwnedPendingRequests() async throws {
        let owned = request(identifier: "\(UrgencyNotificationMetadata.prefix)invalid")
        let configured = request(identifier: ReminderPlanner.dailyReminderIdentifier)
        let center = UrgencyTestNotificationCenter(status: .denied, pending: [owned, configured])
        let reconciler = UrgencyNotificationReconciler(
            center: center,
            ledger: InMemoryUrgencyDeliveredLedger()
        )

        let result = await reconciler.reconcile(desired: [], now: Date())

        #expect(result == .disabledBySystem)
        #expect(center.pending[owned.identifier] == nil)
        #expect(center.pending[configured.identifier] != nil)
    }

    @Test func capacityKeepsEarliestEngineCandidatesWithoutTouchingConfiguredRequests() async throws {
        let configured = request(identifier: ReminderPlanner.dailyReminderIdentifier)
        let center = UrgencyTestNotificationCenter(status: .authorized, pending: [configured])
        let reconciler = UrgencyNotificationReconciler(
            center: center,
            ledger: InMemoryUrgencyDeliveredLedger(),
            maximumPendingRequests: 2
        )
        let now = Date()
        let early = planned(trigger: now.addingTimeInterval(120), scope: "early")
        let late = planned(trigger: now.addingTimeInterval(240), scope: "late")

        let result = await reconciler.reconcile(desired: [late, early], now: now)

        guard case .reconciled(let outcome) = result else {
            Issue.record("Expected reconciliation")
            return
        }
        #expect(outcome.scheduled == [early.record.identity.canonicalKey])
        #expect(outcome.capacityDropped == [late.record.identity.canonicalKey])
        #expect(center.pending[configured.identifier] != nil)
    }

    @Test func capacityCleanupFreesMalformedAndStaleBeforeAddingEarliestDesired() async throws {
        let now = Date()
        let stale = planned(trigger: now.addingTimeInterval(600), scope: "stale")
        let staleRequest = try UrgencyNotificationRequestFactory.make(
            plan: stale, nowMillis: Int64(now.timeIntervalSince1970 * 1_000)
        )
        let malformed = request(identifier: "\(UrgencyNotificationMetadata.prefix)malformed")
        let desired = planned(trigger: now.addingTimeInterval(120), scope: "desired")
        let configured = request(identifier: ReminderPlanner.dailyReminderIdentifier)
        let center = UrgencyTestNotificationCenter(status: .authorized, pending: [staleRequest, malformed, configured], maximumPendingRequests: 3)
        let reconciler = UrgencyNotificationReconciler(center: center, ledger: InMemoryUrgencyDeliveredLedger(), maximumPendingRequests: 2)

        let result = await reconciler.reconcile(desired: [desired], now: now)

        guard case .reconciled(let outcome) = result else { Issue.record("Expected reconciliation"); return }
        #expect(center.pending[desired.record.identity.canonicalKey] != nil)
        #expect(center.pending[stale.record.identity.canonicalKey] == nil)
        #expect(center.pending[malformed.identifier] == nil)
        #expect(center.pending[configured.identifier] != nil)
        #expect(outcome.removed == [stale.record.identity.canonicalKey])
        #expect(outcome.malformedRemoved == [malformed.identifier])
    }

    @Test func replacesSameIdentifierWhenRemainingCopyChanges() async throws {
        let now = Date()
        let goalID = UUID()
        let original = planned(
            trigger: now.addingTimeInterval(120),
            goalID: goalID,
            remaining: 2
        )
        let existing = try UrgencyNotificationRequestFactory.make(
            plan: original,
            nowMillis: Int64(now.timeIntervalSince1970 * 1_000)
        )
        let changed = planned(
            trigger: now.addingTimeInterval(120),
            goalID: goalID,
            remaining: 1
        )
        let center = UrgencyTestNotificationCenter(status: .authorized, pending: [existing])
        let reconciler = UrgencyNotificationReconciler(center: center, ledger: InMemoryUrgencyDeliveredLedger())

        let result = await reconciler.reconcile(desired: [changed], now: now)

        guard case .reconciled(let outcome) = result else { Issue.record("Expected reconciliation"); return }
        #expect(outcome.replaced == [changed.record.identity.canonicalKey])
        #expect(center.added == [changed.record.identity.canonicalKey])
    }

    @Test func replacesSameIdentifierWhenLanguageChanges() async throws {
        let now = Date()
        let goalID = UUID()
        let english = planned(
            trigger: now.addingTimeInterval(120),
            goalID: goalID,
            language: .english
        )
        let existing = try UrgencyNotificationRequestFactory.make(
            plan: english,
            nowMillis: Int64(now.timeIntervalSince1970 * 1_000)
        )
        let arabic = planned(
            trigger: now.addingTimeInterval(120),
            goalID: goalID,
            language: .arabic
        )
        let center = UrgencyTestNotificationCenter(status: .authorized, pending: [existing])
        let reconciler = UrgencyNotificationReconciler(center: center, ledger: InMemoryUrgencyDeliveredLedger())

        let result = await reconciler.reconcile(desired: [arabic], now: now)

        guard case .reconciled(let outcome) = result else { Issue.record("Expected reconciliation"); return }
        #expect(outcome.replaced == [arabic.record.identity.canonicalKey])
        #expect(center.added == [arabic.record.identity.canonicalKey])
    }

    @Test func identicalRequestIsUnchanged() async throws {
        let now = Date()
        let plan = planned(trigger: now.addingTimeInterval(120))
        let existing = try UrgencyNotificationRequestFactory.make(
            plan: plan,
            nowMillis: Int64(now.timeIntervalSince1970 * 1_000)
        )
        let center = UrgencyTestNotificationCenter(status: .authorized, pending: [existing])
        let reconciler = UrgencyNotificationReconciler(center: center, ledger: InMemoryUrgencyDeliveredLedger())

        let result = await reconciler.reconcile(desired: [plan], now: now)

        guard case .reconciled(let outcome) = result else { Issue.record("Expected reconciliation"); return }
        #expect(outcome.unchanged == [plan.record.identity.canonicalKey])
        #expect(center.added.isEmpty)
    }

    @Test func missingContentFingerprintIsReplaced() async throws {
        let now = Date()
        let plan = planned(trigger: now.addingTimeInterval(120))
        let existing = try UrgencyNotificationRequestFactory.make(
            plan: plan,
            nowMillis: Int64(now.timeIntervalSince1970 * 1_000)
        )
        let legacyContent = try #require(existing.content.mutableCopy() as? UNMutableNotificationContent)
        legacyContent.userInfo.removeValue(forKey: "awrad.urgency.content_fingerprint")
        let legacy = UNNotificationRequest(
            identifier: existing.identifier,
            content: legacyContent,
            trigger: existing.trigger
        )
        let center = UrgencyTestNotificationCenter(status: .authorized, pending: [legacy])
        let reconciler = UrgencyNotificationReconciler(center: center, ledger: InMemoryUrgencyDeliveredLedger())

        let result = await reconciler.reconcile(desired: [plan], now: now)

        guard case .reconciled(let outcome) = result else { Issue.record("Expected reconciliation"); return }
        #expect(outcome.replaced == [plan.record.identity.canonicalKey])
    }

    @Test func unknownContentFingerprintVersionIsReplaced() async throws {
        let now = Date()
        let plan = planned(trigger: now.addingTimeInterval(120))
        let existing = try UrgencyNotificationRequestFactory.make(
            plan: plan,
            nowMillis: Int64(now.timeIntervalSince1970 * 1_000)
        )
        let legacyContent = try #require(existing.content.mutableCopy() as? UNMutableNotificationContent)
        legacyContent.userInfo["awrad.urgency.content_fingerprint_version"] = 99
        let legacy = UNNotificationRequest(
            identifier: existing.identifier,
            content: legacyContent,
            trigger: existing.trigger
        )
        let center = UrgencyTestNotificationCenter(status: .authorized, pending: [legacy])
        let reconciler = UrgencyNotificationReconciler(center: center, ledger: InMemoryUrgencyDeliveredLedger())

        let result = await reconciler.reconcile(desired: [plan], now: now)

        guard case .reconciled(let outcome) = result else { Issue.record("Expected reconciliation"); return }
        #expect(outcome.replaced == [plan.record.identity.canonicalKey])
    }

    @Test func contentFingerprintIsDeterministicAcrossRequestRecreation() throws {
        let plan = planned(trigger: Date().addingTimeInterval(120))
        let nowMillis = Int64(Date().timeIntervalSince1970 * 1_000)

        let first = try UrgencyNotificationRequestFactory.make(plan: plan, nowMillis: nowMillis)
        let second = try UrgencyNotificationRequestFactory.make(plan: plan, nowMillis: nowMillis)

        #expect(
            first.content.userInfo["awrad.urgency.content_fingerprint"] as? String ==
                second.content.userInfo["awrad.urgency.content_fingerprint"] as? String
        )
    }

    @Test func metadataParserRejectsTamperedFingerprint() throws {
        let plan = planned(trigger: Date().addingTimeInterval(120))
        let request = try UrgencyNotificationRequestFactory.make(
            plan: plan,
            nowMillis: Int64(Date().timeIntervalSince1970 * 1_000)
        )
        let tamperedContent = try #require(request.content.mutableCopy() as? UNMutableNotificationContent)
        tamperedContent.userInfo["awrad.urgency.content_fingerprint"] = String(repeating: "0", count: 64)
        let tampered = UNNotificationRequest(
            identifier: request.identifier,
            content: tamperedContent,
            trigger: request.trigger
        )

        #expect(UrgencyNotificationMetadata.parse(tampered) == nil)
    }

    @Test func presentationPropertyMutationsReplaceSameIdentifier() async throws {
        let now = Date()
        let plan = planned(trigger: now.addingTimeInterval(120))
        let mutations: [(String, (UNMutableNotificationContent) throws -> Void)] = [
            ("sound", { $0.sound = nil }),
            ("badge", { $0.badge = 1 }),
            ("launch image", { $0.launchImageName = "launch-image" }),
            ("target content", { $0.targetContentIdentifier = "target-content" }),
            ("summary", {
                $0.summaryArgument = "summary"
                $0.summaryArgumentCount = 2
            }),
            ("interruption and relevance", {
                $0.interruptionLevel = .timeSensitive
                $0.relevanceScore = 0.5
            }),
            ("attachment", { content in
                content.attachments = [try self.attachment()]
            }),
            ("navigation user info", {
                $0.userInfo["awrad.navigation.destination"] = "goal-detail"
            })
        ]

        for (name, mutate) in mutations {
            let existing = try mutatedRequest(plan: plan, now: now, mutate)
            let center = UrgencyTestNotificationCenter(status: .authorized, pending: [existing])
            let reconciler = UrgencyNotificationReconciler(center: center, ledger: InMemoryUrgencyDeliveredLedger())

            let result = await reconciler.reconcile(desired: [plan], now: now)

            guard case .reconciled(let outcome) = result else {
                Issue.record("Expected reconciliation for \(name)")
                return
            }
            #expect(outcome.replaced == [plan.record.identity.canonicalKey], "Expected replacement for \(name)")
        }
    }

    @Test func canonicalUserInfoDictionaryOrderDoesNotChangeFingerprint() throws {
        let plan = planned(trigger: Date().addingTimeInterval(120))
        let nowMillis = Int64(Date().timeIntervalSince1970 * 1_000)
        let first = try UrgencyNotificationRequestFactory.make(plan: plan, nowMillis: nowMillis)
        let second = try UrgencyNotificationRequestFactory.make(plan: plan, nowMillis: nowMillis)
        let firstContent = try #require(first.content.mutableCopy() as? UNMutableNotificationContent)
        let secondContent = try #require(second.content.mutableCopy() as? UNMutableNotificationContent)
        firstContent.userInfo["awrad.navigation.payload"] = [
            "alpha": ["first", Int(1)],
            "beta": ["nested": true, "count": UInt(1)]
        ]
        secondContent.userInfo["awrad.navigation.payload"] = [
            "beta": ["count": UInt(1), "nested": true],
            "alpha": ["first", Int(1)]
        ]

        let firstFingerprint = try #require(
            UrgencyNotificationRequestFactory.contentFingerprint(for: firstContent)
        )
        let secondFingerprint = try #require(
            UrgencyNotificationRequestFactory.contentFingerprint(for: secondContent)
        )
        #expect(firstFingerprint == secondFingerprint)
    }

    @Test func typedNumericUserInfoValuesProduceDistinctFingerprints() throws {
        let plan = planned(trigger: Date().addingTimeInterval(120))
        let nowMillis = Int64(Date().timeIntervalSince1970 * 1_000)
        let values: [(String, Any)] = [
            ("int", Int(1)),
            ("uint", UInt(1)),
            ("double", Double(1.0)),
            ("float", Float(1.0)),
            ("bool", true)
        ]
        var fingerprints: [String: String] = [:]
        for (name, value) in values {
            fingerprints[name] = try fingerprint(plan: plan, nowMillis: nowMillis, value: value)
        }

        let unique = Set(fingerprints.values)
        #expect(unique.count == values.count, "Expected distinct fingerprints, got \(fingerprints)")
    }

    @Test func sameTypedNumericUserInfoValueIsDeterministic() throws {
        let plan = planned(trigger: Date().addingTimeInterval(120))
        let nowMillis = Int64(Date().timeIntervalSince1970 * 1_000)
        let samples: [Any] = [Int(1), UInt(1), Double(1.0), Float(1.0), true, Double(-0.0), Float(-0.0)]
        for sample in samples {
            let first = try fingerprint(plan: plan, nowMillis: nowMillis, value: sample)
            let second = try fingerprint(plan: plan, nowMillis: nowMillis, value: sample)
            #expect(first == second)
        }
        let positiveZero = try fingerprint(plan: plan, nowMillis: nowMillis, value: Double(0.0))
        let negativeZero = try fingerprint(plan: plan, nowMillis: nowMillis, value: Double(-0.0))
        #expect(positiveZero != negativeZero)
    }

    @Test func typedNumericUserInfoMutationReplacesSameIdentifier() async throws {
        let now = Date()
        let plan = planned(trigger: now.addingTimeInterval(120))
        let nowMillis = Int64(now.timeIntervalSince1970 * 1_000)
        let pairs: [(String, Any, Any)] = [
            ("int-to-uint", Int(1), UInt(1)),
            ("int-to-double", Int(1), Double(1.0)),
            ("int-to-float", Int(1), Float(1.0)),
            ("int-to-true", Int(1), true),
            ("double-to-float", Double(1.0), Float(1.0)),
            ("true-to-int", true, Int(1))
        ]

        for (name, existingValue, otherValue) in pairs {
            let existingFingerprint = try fingerprint(plan: plan, nowMillis: nowMillis, value: existingValue)
            let otherFingerprint = try fingerprint(plan: plan, nowMillis: nowMillis, value: otherValue)
            #expect(existingFingerprint != otherFingerprint, "Expected distinct fingerprints for \(name)")

            let existing = try requestWithTypedUserInfo(plan: plan, now: now, value: existingValue)
            #expect(UrgencyNotificationMetadata.parse(existing)?.contentFingerprint == existingFingerprint)

            let center = UrgencyTestNotificationCenter(status: .authorized, pending: [existing])
            let reconciler = UrgencyNotificationReconciler(center: center, ledger: InMemoryUrgencyDeliveredLedger())
            let result = await reconciler.reconcile(desired: [plan], now: now)
            guard case .reconciled(let outcome) = result else {
                Issue.record("Expected reconciliation for \(name)")
                return
            }
            #expect(outcome.replaced == [plan.record.identity.canonicalKey], "Expected replacement for \(name)")
        }
    }

    @Test func decimalNumberUserInfoFailsClosed() throws {
        let plan = planned(trigger: Date().addingTimeInterval(120))
        let request = try UrgencyNotificationRequestFactory.make(
            plan: plan,
            nowMillis: Int64(Date().timeIntervalSince1970 * 1_000)
        )
        let content = try #require(request.content.mutableCopy() as? UNMutableNotificationContent)
        content.userInfo["awrad.navigation.decimal"] = NSDecimalNumber(value: 1)
        #expect(UrgencyNotificationRequestFactory.contentFingerprint(for: content) == nil)
    }

    @Test func unsupportedUserInfoValueFailsClosed() throws {
        let plan = planned(trigger: Date().addingTimeInterval(120))
        let request = try UrgencyNotificationRequestFactory.make(
            plan: plan,
            nowMillis: Int64(Date().timeIntervalSince1970 * 1_000)
        )
        let content = try #require(request.content.mutableCopy() as? UNMutableNotificationContent)
        content.userInfo["awrad.navigation.unsupported"] = URL(string: "https://example.com")!
        let tampered = UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: request.trigger
        )

        #expect(UrgencyNotificationRequestFactory.contentFingerprint(for: content) == nil)
        #expect(UrgencyNotificationMetadata.parse(tampered) == nil)
    }

    private func mutatedRequest(
        plan: PlannedNotificationNudge,
        now: Date,
        _ mutate: (UNMutableNotificationContent) throws -> Void
    ) throws -> UNNotificationRequest {
        let request = try UrgencyNotificationRequestFactory.make(
            plan: plan,
            nowMillis: Int64(now.timeIntervalSince1970 * 1_000)
        )
        let content = try #require(request.content.mutableCopy() as? UNMutableNotificationContent)
        try mutate(content)
        return UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: request.trigger
        )
    }

    private func fingerprint(
        plan: PlannedNotificationNudge,
        nowMillis: Int64,
        value: Any
    ) throws -> String {
        let request = try UrgencyNotificationRequestFactory.make(plan: plan, nowMillis: nowMillis)
        let content = try #require(request.content.mutableCopy() as? UNMutableNotificationContent)
        content.userInfo["awrad.navigation.typed"] = value
        return try #require(UrgencyNotificationRequestFactory.contentFingerprint(for: content))
    }

    private func requestWithTypedUserInfo(
        plan: PlannedNotificationNudge,
        now: Date,
        value: Any
    ) throws -> UNNotificationRequest {
        let request = try UrgencyNotificationRequestFactory.make(
            plan: plan,
            nowMillis: Int64(now.timeIntervalSince1970 * 1_000)
        )
        let content = try #require(request.content.mutableCopy() as? UNMutableNotificationContent)
        content.userInfo["awrad.navigation.typed"] = value
        content.userInfo.removeValue(forKey: UrgencyNotificationMetadata.contentFingerprint)
        let fingerprint = try #require(UrgencyNotificationRequestFactory.contentFingerprint(for: content))
        content.userInfo[UrgencyNotificationMetadata.contentFingerprint] = fingerprint
        return UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: request.trigger
        )
    }

    private func attachment() throws -> UNNotificationAttachment {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("urgency-notification-\(UUID().uuidString).gif")
        let image = try #require(Data(base64Encoded: "R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw=="))
        try image.write(to: url)
        return try UNNotificationAttachment(
            identifier: "urgency-attachment",
            url: url,
            options: [UNNotificationAttachmentOptionsTypeHintKey: "com.compuserve.gif"]
        )
    }

    private func planned(
        trigger: Date,
        scope: String = "scope",
        goalID: UUID = UUID(),
        remaining: Int64? = 1,
        language: AppLanguage = .english
    ) -> PlannedNotificationNudge {
        let id = goalID
        let key = NotificationNudgeCandidateKey(
            goalID: id,
            scope: scope,
            slotID: nil,
            kind: .deadlineWarning
        )
        let triggerMillis = Int64(trigger.timeIntervalSince1970 * 1_000)
        return PlannedNotificationNudge(
            record: .init(
                identity: .init(key),
                triggerMillis: triggerMillis,
                expiryMillis: triggerMillis + 60_000
            ),
            goalID: id,
            goalName: "Dhikr",
            slotID: nil,
            slotType: nil,
            progress: 0,
            remaining: remaining,
            currentStreak: 0,
            language: language
        )
    }

    private func request(identifier: String) -> UNNotificationRequest {
        UNNotificationRequest(identifier: identifier, content: UNMutableNotificationContent(), trigger: nil)
    }
}

@MainActor
private final class UrgencyTestNotificationCenter: UrgencyNotificationCenter {
    var status: UNAuthorizationStatus
    private(set) var pending: [String: UNNotificationRequest]
    private(set) var delivered: [DeliveredUserNotification] = []
    private(set) var added: [String] = []
    private(set) var removedPending: [String] = []
    private(set) var requestAuthorizationCount = 0
    private let maximumPendingRequests: Int

    init(status: UNAuthorizationStatus, pending: [UNNotificationRequest] = [], maximumPendingRequests: Int = 64) {
        self.status = status
        self.pending = Dictionary(uniqueKeysWithValues: pending.map { ($0.identifier, $0) })
        self.maximumPendingRequests = maximumPendingRequests
    }

    func authorizationStatus() async throws -> UNAuthorizationStatus { status }
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestAuthorizationCount += 1
        return false
    }
    func pendingRequests() async throws -> [UNNotificationRequest] { Array(pending.values) }
    func deliveredNotifications() async throws -> [DeliveredUserNotification] { delivered }
    func add(_ request: UNNotificationRequest) async throws {
        if pending[request.identifier] == nil, pending.count >= maximumPendingRequests {
            throw UrgencyTestError.capacityExceeded
        }
        pending[request.identifier] = request
        added.append(request.identifier)
    }
    func removePending(withIdentifiers identifiers: [String]) {
        removedPending.append(contentsOf: identifiers)
        identifiers.forEach { pending.removeValue(forKey: $0) }
    }
    func removeDelivered(withIdentifiers identifiers: [String]) {}

    func insert(request: UNNotificationRequest) {
        pending[request.identifier] = request
    }
}

private enum UrgencyTestError: Error { case capacityExceeded }
