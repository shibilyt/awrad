import Foundation

// Rule: completion (contracts/goal-model/v1/fixtures/goal_completion.json).

extension Goal {
    /// Whether the goal is completed on `day`. Derived from the completion policy, so a
    /// correction that drops the total below the target un-completes it, until the list writes
    /// the goal's `completed` ending (`GoalTimeline.finish`).
    ///
    /// - `whenTargetReached`: a cumulative goal whose total, from the start date up to `day`
    ///   (and no later than the active period's last day), reaches its target. Other requirements
    ///   have no single target to reach, so they never complete this way.
    /// - `whenDurationEnded`: `day` is after the active period's last day.
    public func isCompleted(on day: CalendarDay, counts: [CountEntry]) -> Bool {
        isCompleted(on: day, ledger: CountLedger(counts))
    }

    func isCompleted(on day: CalendarDay, ledger: CountLedger) -> Bool {
        switch completion {
        case .never:
            return false
        case .whenDurationEnded:
            return activePeriod.lastDay.map { day > $0 } ?? false
        case .whenTargetReached:
            guard requirement == .cumulativeTotal, day >= activePeriod.start else { return false }
            let through = activePeriod.lastDay.map { min(day, $0) } ?? day
            return progress(in: activePeriod.start...through, through: through, ledger: ledger).isMet
        }
    }
}
