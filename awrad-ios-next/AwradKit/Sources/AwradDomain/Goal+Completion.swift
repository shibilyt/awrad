import Foundation

// Rule: completion (contracts/goal-model/v1/fixtures/goal_completion.json).

extension Goal {
    /// Whether the goal is completed on `day`. Derived from the completion policy, never stored,
    /// so a correction that drops the total below the target un-completes it.
    ///
    /// - `whenTargetReached`: a cumulative goal whose total, from the start date up to `day`
    ///   (and no later than the active period's last day), reaches its target. Other requirements
    ///   have no single target to reach, so they never complete this way.
    /// - `whenDurationEnded`: `day` is after the active period's last day.
    public func isCompleted(on day: CalendarDay, counts: [CountEntry]) -> Bool {
        switch completion {
        case .never:
            return false
        case .whenDurationEnded:
            return activePeriod.lastDay.map { day > $0 } ?? false
        case .whenTargetReached:
            guard requirement == .cumulativeTotal, day >= activePeriod.start else { return false }
            let through = activePeriod.lastDay.map { min(day, $0) } ?? day
            let window = activePeriod.start...through
            return progress(in: window, through: through, ledger: CountLedger(counts), threshold: targetThreshold)
                .isMet
        }
    }
}
