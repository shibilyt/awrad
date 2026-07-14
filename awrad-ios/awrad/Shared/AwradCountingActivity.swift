import Foundation

#if canImport(ActivityKit)
import ActivityKit

/// Live Activity attributes shared between the app (which starts/updates/ends
/// the activity) and the widget extension (which renders it on the Lock Screen
/// and in the Dynamic Island).
struct AwradCountingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var currentCount: Int64
        var targetCount: Int64
        var isPlaying: Bool
        var audioPositionText: String

        var progress: Double {
            guard targetCount > 0 else { return 0 }
            return min(Double(currentCount) / Double(targetCount), 1)
        }
    }

    var dhikrTitle: String
    var goalID: String
}
#endif
