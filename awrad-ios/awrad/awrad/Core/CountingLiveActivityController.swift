import Foundation

#if canImport(ActivityKit)
import ActivityKit

/// Drives the counting Live Activity. All calls are safe to make unconditionally;
/// the controller no-ops when Live Activities are unavailable or disabled.
@MainActor
final class CountingLiveActivityController {
    private var activity: Activity<AwradCountingActivityAttributes>?
    private var operationID = UUID()

    func start(dhikrTitle: String, goalID: String, currentCount: Int64, targetCount: Int64, isPlaying: Bool) {
        guard #available(iOS 16.1, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let operationID = UUID()
        self.operationID = operationID
        let attributes = AwradCountingActivityAttributes(dhikrTitle: dhikrTitle, goalID: goalID)
        let state = AwradCountingActivityAttributes.ContentState(
            currentCount: currentCount,
            targetCount: targetCount,
            isPlaying: isPlaying,
            audioPositionText: ""
        )
        Task {
            // ActivityKit can retain an activity after process termination. End
            // stale activities for this goal before creating its replacement.
            for staleActivity in Activity<AwradCountingActivityAttributes>.activities
                where staleActivity.attributes.goalID == goalID {
                await staleActivity.end(nil, dismissalPolicy: .immediate)
            }
            guard self.operationID == operationID else { return }
            do {
                activity = try Activity.request(
                    attributes: attributes,
                    content: .init(state: state, staleDate: nil)
                )
            } catch {
                activity = nil
            }
        }
    }

    func update(currentCount: Int64, targetCount: Int64, isPlaying: Bool, audioPositionText: String) {
        guard #available(iOS 16.1, *), let activity else { return }
        let state = AwradCountingActivityAttributes.ContentState(
            currentCount: currentCount,
            targetCount: targetCount,
            isPlaying: isPlaying,
            audioPositionText: audioPositionText
        )
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    func end() {
        operationID = UUID()
        guard #available(iOS 16.1, *), let activity else {
            self.activity = nil
            return
        }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
#else
@MainActor
final class CountingLiveActivityController {
    func start(dhikrTitle: String, goalID: String, currentCount: Int64, targetCount: Int64, isPlaying: Bool) {}
    func update(currentCount: Int64, targetCount: Int64, isPlaying: Bool, audioPositionText: String) {}
    func end() {}
}
#endif
