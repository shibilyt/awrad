import Foundation

// Rule: count attribution (contracts/goal-model/v1/fixtures/count_attribution.json).

/// Turns the count log into the `CountEntry` lists every other goal rule reads. Counts belong to
/// the dhikr (root ADR-2026-10-31).
public enum CountAttribution {
    /// Goal `goalID`'s counts per day and session, oldest first (no session first on a day).
    ///
    /// - A shared goal takes every entry of its dhikr without a goal, wherever it was made; a
    ///   dedicated goal takes only the entries made in it.
    /// - With sessions in that day's version, an entry goes to its session, and entries without
    ///   one, or with a session the goal doesn't have, are dropped. Without sessions it goes to
    ///   the day.
    /// - Entries sum per day and session, and a sum of 0 or less is no count. Dates aren't
    ///   filtered: the rules ignore counts outside the active period.
    public static func entries(
        goalID: AwradID, dhikrID: AwradID, counts: GoalCounts, timeline: GoalTimeline, log: [CountLogEntry]
    ) -> [CountEntry] {
        var sums: [Bucket: Int64] = [:]
        for entry in log where entry.dhikrID == dhikrID {
            let isMine = counts == .dedicated ? entry.goalID == goalID : entry.goalID == nil
            guard isMine else { continue }
            let sessions = timeline.uncappedGoal(on: entry.practiceDay).sessions
            var session: String?
            if !sessions.isEmpty {
                guard let id = entry.sessionID, sessions.contains(where: { $0.id == id }) else { continue }
                session = id
            }
            sums[Bucket(day: entry.practiceDay, session: session), default: 0].addSaturating(entry.amount)
        }
        return sums.filter { $0.value > 0 }
            .map { CountEntry(day: $0.key.day, session: $0.key.session, count: $0.value) }
            .sorted { ($0.day, $0.session ?? "") < ($1.day, $1.session ?? "") }
    }

    private struct Bucket: Hashable {
        let day: CalendarDay
        let session: String?
    }
}

extension GoalDocument {
    /// This goal's counts from the profile's count log (`CountAttribution`).
    public func countEntries(goalID: AwradID, from log: [CountLogEntry]) -> [CountEntry] {
        CountAttribution.entries(goalID: goalID, dhikrID: dhikrID, counts: counts, timeline: timeline, log: log)
    }
}
