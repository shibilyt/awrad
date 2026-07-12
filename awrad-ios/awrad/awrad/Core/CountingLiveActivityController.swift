import Foundation

#if canImport(ActivityKit)
import ActivityKit

/// Drives the counting Live Activity. All calls are safe to make unconditionally;
/// the controller no-ops when Live Activities are unavailable or disabled.
@MainActor
final class CountingLiveActivityController {
    private var activity: Any?

    func start(dhikrTitle: String, goalID: String, currentCount: Int, targetCount: Int, isPlaying: Bool) {
        guard #available(iOS 16.1, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Replace any stale activity first.
        end()
        let attributes = AwradCountingActivityAttributes(dhikrTitle: dhikrTitle, goalID: goalID)
        let state = AwradCountingActivityAttributes.ContentState(
            currentCount: currentCount,
            targetCount: targetCount,
            isPlaying: isPlaying,
            audioPositionText: ""
        )
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
        } catch {
            activity = nil
        }
    }

    func update(currentCount: Int, targetCount: Int, isPlaying: Bool, audioPositionText: String) {
        guard #available(iOS 16.1, *),
              let activity = activity as? Activity<AwradCountingActivityAttributes> else { return }
        let state = AwradCountingActivityAttributes.ContentState(
            currentCount: currentCount,
            targetCount: targetCount,
            isPlaying: isPlaying,
            audioPositionText: audioPositionText
        )
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    func end() {
        guard #available(iOS 16.1, *),
              let activity = activity as? Activity<AwradCountingActivityAttributes> else {
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
    func start(dhikrTitle: String, goalID: String, currentCount: Int, targetCount: Int, isPlaying: Bool) {}
    func update(currentCount: Int, targetCount: Int, isPlaying: Bool, audioPositionText: String) {}
    func end() {}
}
#endif
