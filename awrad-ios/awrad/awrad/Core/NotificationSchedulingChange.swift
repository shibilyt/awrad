import Foundation
import Observation

/// Store-owned post-commit seam. It intentionally does not reference AppServices so
/// persistence mutations remain local-first and never wait on notification scheduling.
@Observable
@MainActor
final class NotificationSchedulingChanges {
    private(set) var revision = 0
    private(set) var latest = NotificationSchedulingChange(goalIDs: [], reason: .syncAll)

    func emit(goalIDs: Set<AwradID>, reason: NotificationSchedulingChangeReason) {
        latest = NotificationSchedulingChange(goalIDs: goalIDs, reason: reason)
        revision &+= 1
    }
}

struct NotificationSchedulingChange: Sendable {
    let goalIDs: Set<AwradID>
    let reason: NotificationSchedulingChangeReason

    /// Delivered urgency removal does not require scheduling authorization. Explicit disable and
    /// local-reset/syncAll therefore clean independently of reconciliation outcome; ordinary
    /// goal/count affected-ID cleanup stays gated on successful reconciliation.
    static func deliveredCleanupRequest(
        change: NotificationSchedulingChange?,
        urgencyRemindersEnabled: Bool
    ) -> UrgencyDeliveredCleanupRequest? {
        if !urgencyRemindersEnabled {
            return UrgencyDeliveredCleanupRequest(
                goalIDs: [],
                removeAll: true,
                timing: .independentOfReconciliation
            )
        }
        guard let change else { return nil }
        switch change.reason {
        case .syncAll:
            return UrgencyDeliveredCleanupRequest(
                goalIDs: change.goalIDs,
                removeAll: true,
                timing: .independentOfReconciliation
            )
        case .preferenceMutation:
            return UrgencyDeliveredCleanupRequest(
                goalIDs: change.goalIDs,
                removeAll: true,
                timing: .afterSuccessfulReconciliation
            )
        case .goalMutation, .countMutation, .capacityRefresh:
            return UrgencyDeliveredCleanupRequest(
                goalIDs: change.goalIDs,
                removeAll: false,
                timing: .afterSuccessfulReconciliation
            )
        }
    }
}

enum UrgencyDeliveredCleanupTiming: Sendable, Equatable {
    /// Safe for affected-ID cleanup that should not race a failed reconcile.
    case afterSuccessfulReconciliation
    /// Safe because removing delivered notifications does not require scheduling authorization.
    case independentOfReconciliation
}

struct UrgencyDeliveredCleanupRequest: Sendable, Equatable {
    let goalIDs: Set<AwradID>
    let removeAll: Bool
    let timing: UrgencyDeliveredCleanupTiming
}

enum NotificationSchedulingChangeReason: Sendable, Equatable, Hashable {
    case goalMutation
    case countMutation
    case preferenceMutation
    case capacityRefresh
    case syncAll

    var removesAllDeliveredUrgency: Bool {
        switch self {
        case .preferenceMutation, .syncAll: true
        case .goalMutation, .countMutation, .capacityRefresh: false
        }
    }

    static func merged(
        _ lhs: NotificationSchedulingChangeReason,
        _ rhs: NotificationSchedulingChangeReason
    ) -> NotificationSchedulingChangeReason {
        let priorities: [NotificationSchedulingChangeReason: Int] = [
            .countMutation: 0,
            .goalMutation: 1,
            .capacityRefresh: 2,
            .preferenceMutation: 3,
            .syncAll: 4
        ]
        return (priorities[lhs] ?? 0) >= (priorities[rhs] ?? 0) ? lhs : rhs
    }
}
