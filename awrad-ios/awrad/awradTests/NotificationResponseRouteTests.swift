import Foundation
import Testing
import UserNotifications
@testable import awrad

@MainActor
struct NotificationResponseRouteTests {
    @Test func validEngineMetadataRoutesToGoalAndSlot() {
        let goalID = UUID()
        let slotID = UUID()
        let identity = urgencyIdentity(goalID: goalID, slotID: slotID)
        let request = request(
            identifier: identity,
            userInfo: validMetadata(identity: identity, goalID: goalID, slotID: slotID)
        )

        #expect(NotificationResponseRoute.parse(request) == .counting(goalID: goalID, slotID: slotID))
    }

    @Test func validEngineMetadataWithoutSlotRoutesToGoal() {
        let goalID = UUID()
        let identity = urgencyIdentity(goalID: goalID, slotID: nil)
        let request = request(
            identifier: identity,
            userInfo: validMetadata(identity: identity, goalID: goalID, slotID: nil)
        )

        #expect(NotificationResponseRoute.parse(request) == .goalDetail(goalID: goalID))
    }

    @Test func malformedOrNonEngineRequestsAreIgnored() {
        let malformed = request(identifier: "\(UrgencyNotificationMetadata.prefix)invalid", userInfo: [:])
        let unrelated = request(identifier: "awrad.daily-reminder", userInfo: [:])

        #expect(NotificationResponseRoute.parse(malformed) == nil)
        #expect(NotificationResponseRoute.parse(unrelated) == nil)
    }

    private func urgencyIdentity(goalID: UUID, slotID: UUID?) -> String {
        NotificationNudgeIdentity(
            .init(goalID: goalID, scope: "test", slotID: slotID, kind: .deadlineWarning)
        ).canonicalKey
    }

    private func validMetadata(identity: String, goalID: UUID, slotID: UUID?) -> [AnyHashable: Any] {
        var value: [AnyHashable: Any] = [
            UrgencyNotificationMetadata.identity: identity,
            UrgencyNotificationMetadata.kind: NotificationNudgeKind.deadlineWarning.rawValue,
            UrgencyNotificationMetadata.goalID: goalID.uuidString.lowercased(),
            UrgencyNotificationMetadata.scope: "test",
            UrgencyNotificationMetadata.triggerMillis: Int64(1_000),
            UrgencyNotificationMetadata.expiryMillis: Int64(2_000),
            UrgencyNotificationMetadata.format: UrgencyNotificationMetadata.version
        ]
        if let slotID { value[UrgencyNotificationMetadata.slotID] = slotID.uuidString.lowercased() }
        return value
    }

    private func request(identifier: String, userInfo: [AnyHashable: Any]) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.userInfo = userInfo
        return UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
    }
}
