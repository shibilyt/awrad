import Foundation

// Rule: consistency (contracts/goal-model/v1/fixtures/consistency.json).

/// The gentle consistency tag, and what a goal's row shows (decisions 19, 21 and 32).
public struct Consistency: Hashable, Sendable {
    /// What the tag counts.
    public enum Basis: String, CaseIterable, Hashable, Sendable {
        /// The last 30 due days, for daily rhythms (days, a weekday, occasions).
        case dueDays = "due_days"
        /// The last 12 periods, for weekly and monthly goals.
        case periods
    }

    public enum Tag: String, CaseIterable, Hashable, Sendable {
        /// 90% or more.
        case devoted
        /// 80% or more.
        case steady
    }

    /// What a row shows next to the goal.
    public enum Display: String, CaseIterable, Hashable, Sendable {
        /// 🔥 and the streak.
        case streak
        /// The tag ("Steady · 25/30").
        case consistency
        case none
    }

    public var basis: Basis
    /// Due days kept, or periods met, in the window.
    public var met: Int
    /// The window's settled due days or periods.
    public var outOf: Int
    /// `nil` before 7 due days or 4 periods, and below 80%.
    public var tag: Tag?
    public var show: Display

    public init(basis: Basis, met: Int, outOf: Int, tag: Tag?, show: Display) {
        self.basis = basis
        self.met = met
        self.outOf = outOf
        self.tag = tag
        self.show = show
    }

    static let dueDayWindow = 30
    static let periodWindow = 12
    static let minimumDueDays = 7
    static let minimumPeriods = 4
}

extension GoalTimeline {
    /// The consistency on `today` (README.md, Consistency). Today, or the current period, is
    /// counted only once kept or met, and a day pending make-up only once its window closes.
    ///
    /// A row shows the streak when it's 3 or more; otherwise the tag, if there is one; otherwise
    /// a streak of 1 or 2; otherwise nothing.
    public func consistency(
        on today: CalendarDay, counts: [CountEntry], weekStart: WeekStart, hijriCorrections: HijriCorrections = .none
    ) -> Consistency {
        TimelineEvaluator(self, counts: counts, hijri: hijriCorrections, weekStart: weekStart).consistency(on: today)
    }
}

extension TimelineEvaluator {
    func consistency(on today: CalendarDay) -> Consistency {
        let statuses = dueDayStatuses(through: today)
        let basis: Consistency.Basis = goal(on: today).streakUnit.isPeriod ? .periods : .dueDays
        let settled: [Bool]
        switch basis {
        case .periods:
            settled = Array(
                periodsBack(from: today).lazy.filter { $0.isMet || !$0.isInProgress }.map(\.isMet)
                    .prefix(Consistency.periodWindow))
        case .dueDays:
            settled = Array(
                statuses.reversed().lazy.map(\.status).filter { !$0.isOpen }.map(\.keepsStreak)
                    .prefix(Consistency.dueDayWindow))
        }
        let met = settled.filter { $0 }.count
        let outOf = settled.count
        let minimum = basis == .periods ? Consistency.minimumPeriods : Consistency.minimumDueDays
        var tag: Consistency.Tag?
        if outOf >= minimum {
            if met * 10 >= outOf * 9 {
                tag = .devoted
            } else if met * 10 >= outOf * 8 {
                tag = .steady
            }
        }
        let streak = currentStreak(on: today, statuses: statuses)
        let show: Consistency.Display =
            streak >= 3 ? .streak : tag != nil ? .consistency : streak >= 1 ? .streak : .none
        return Consistency(basis: basis, met: met, outOf: outOf, tag: tag, show: show)
    }
}
