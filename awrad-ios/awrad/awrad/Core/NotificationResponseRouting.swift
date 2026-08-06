import Foundation
import Observation
import UserNotifications

@Observable
@MainActor
final class NotificationRouteMailbox {
    var pendingRoute: NotificationResponseRoute?
}

enum NotificationResponseRoute: Equatable, Sendable {
    case goalDetail(goalID: AwradID)
    case counting(goalID: AwradID, slotID: AwradID)

    static func parse(_ request: UNNotificationRequest) -> NotificationResponseRoute? {
        guard let decoded = UrgencyNotificationMetadata.decodedIdentity(request.identifier),
              UrgencyNotificationMetadata.parse(request) != nil else {
            return nil
        }
        if let slotID = decoded.slotID {
            return .counting(goalID: decoded.goalID, slotID: slotID)
        }
        return .goalDetail(goalID: decoded.goalID)
    }
}

/// Retained by `AppServices` for the lifetime of the application. The delegate never
/// navigates directly: it records a typed route that the root consumes after bootstrap.
final class AwradNotificationResponseDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let receiveRoute: @MainActor (NotificationResponseRoute) -> Void

    init(receiveRoute: @escaping @MainActor (NotificationResponseRoute) -> Void) {
        self.receiveRoute = receiveRoute
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Preserve the previous foreground behavior: urgency notices are not surfaced
        // while the app is already active.
        completionHandler([])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let route = NotificationResponseRoute.parse(response.notification.request)
        if let route {
            Task { @MainActor [receiveRoute] in receiveRoute(route) }
        }
        completionHandler()
    }
}
