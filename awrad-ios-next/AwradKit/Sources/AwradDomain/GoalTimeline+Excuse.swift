import Foundation

// Rule: excused days (contracts/goal-model/v1/fixtures/excused_days.json, decision 20).

/// Why a day can't be excused or un-excused. The raw value is the contract's reason.
public enum ExcuseRefusal: String, Error, CaseIterable, Hashable, Sendable {
    /// The goal has ended, or is past its last day.
    case goalFinished = "goal_finished"
    /// The day is today or later.
    case notPast = "not_past"
    case alreadyExcused = "already_excused"
    /// Period totals aren't judged by day.
    case notAvailable = "not_available"
    /// Off-schedule, paused or outside the active period.
    case notDue = "not_due"
    /// Met, minimum only or made up; for days per period, a day that qualified.
    case notMissed = "not_missed"
    /// Already 2 excused days in that day's Gregorian month.
    case limitReached = "limit_reached"
    /// Un-excusing a day that isn't excused.
    case notExcused = "not_excused"
}

extension GoalTimeline {
    /// At most this many excused days in one Gregorian month.
    public static let maximumExcusedPerMonth = 2

    /// Why `day` can't be excused on `today`, or `nil` when it can. The checks run in the
    /// contract's order, and the first that fails is the reason. A day pending make-up can be
    /// excused; there's no limit on how far back.
    public func excuseRefusal(
        for day: CalendarDay, today: CalendarDay, counts: [CountEntry], hijriCorrections: HijriCorrections = .none
    ) -> ExcuseRefusal? {
        let evaluator = TimelineEvaluator(self, counts: counts, hijri: hijriCorrections)
        if let refusal = finishedRefusal(evaluator, today: today) { return refusal }
        guard day < today else { return .notPast }
        guard !excused.contains(day) else { return .alreadyExcused }
        if case .periodTotal = evaluator.goal(on: today).requirement { return .notAvailable }
        let goal = evaluator.goal(on: day)
        guard goal.isDue(on: day, hijriCorrections: hijriCorrections) else { return .notDue }
        let isKept: Bool
        if case .daysPerPeriod = goal.requirement {
            isKept = evaluator.meetsDailyTarget(on: day)
        } else {
            let status = evaluator.dueDayStatuses(through: today).first { $0.day == day }?.status
            isKept = status?.keepsStreak ?? false
        }
        guard !isKept else { return .notMissed }
        let sameMonth = excused.filter { $0.year == day.year && $0.month == day.month }
        guard sameMonth.count < Self.maximumExcusedPerMonth else { return .limitReached }
        return nil
    }

    /// Why `day` can't be un-excused on `today`, or `nil` when it can (which frees its place in
    /// that month).
    public func unexcuseRefusal(for day: CalendarDay, today: CalendarDay) -> ExcuseRefusal? {
        let evaluator = TimelineEvaluator(self, counts: [], hijri: .none)
        if let refusal = finishedRefusal(evaluator, today: today) { return refusal }
        return excused.contains(day) ? nil : .notExcused
    }

    private func finishedRefusal(_ evaluator: TimelineEvaluator, today: CalendarDay) -> ExcuseRefusal? {
        ended != nil || !evaluator.isRunning(on: today) ? .goalFinished : nil
    }
}
