import Foundation

// Rules: daily pace (contracts/goal-model/v1/fixtures/daily_pace.json) and today's ring
// (today_ring.json).

/// Today's share of a total goal with an end (decision 28).
public struct DailyPace: Hashable, Sendable {
    /// What's left before today over the due days from today to the last day, rounded up; `nil`
    /// without an end, or when today isn't due.
    public var pace: Int64?
    /// The total less everything counted before today (never below 0); `nil` unless a total
    /// without sessions.
    public var remaining: Int64?
    /// Due days from today to the last day; `nil` without an end.
    public var dueDaysLeft: Int?

    public init(pace: Int64?, remaining: Int64?, dueDaysLeft: Int?) {
        self.pace = pace
        self.remaining = remaining
        self.dueDaysLeft = dueDaysLeft
    }

    static let none = DailyPace(pace: nil, remaining: nil, dueDaysLeft: nil)
}

/// What a list ring fills toward today (decision 33). Every ring means today.
public struct TodayRing: Hashable, Sendable {
    public enum Kind: String, CaseIterable, Hashable, Sendable {
        /// Today's target (daily goals and N days a period; with sessions, their targets combined).
        case target
        /// The week or month so far (period totals).
        case periodTarget = "period_target"
        /// Today's pace share (totals whose streak counts at the pace).
        case pace
        /// The streak amount (other totals, and trackers with a number until it's reached).
        case streakAmount = "streak_amount"
        /// No ring: today isn't due, or a tracker with any count or past its number.
        case none
    }

    public var kind: Kind
    /// Today's (or the period's) count toward `goal`; with sessions each counts up to its target.
    public var progress: Int64
    public var goal: Int64?

    public init(kind: Kind, progress: Int64, goal: Int64?) {
        self.kind = kind
        self.progress = progress
        self.goal = goal
    }
}

extension GoalTimeline {
    /// The daily pace on `day`, fixed for the day: it excludes the day's own counts. Each day is
    /// judged against the end its version had then, even after the goal has ended early. Totals
    /// with sessions have no pace.
    public func dailyPace(
        on day: CalendarDay, counts: [CountEntry], hijriCorrections: HijriCorrections = .none
    ) -> DailyPace {
        TimelineEvaluator(self, counts: counts, hijri: hijriCorrections).dailyPace(on: day)
    }

    /// What the goal's list ring fills toward on `today`.
    public func todayRing(
        on today: CalendarDay, counts: [CountEntry], weekStart: WeekStart, hijriCorrections: HijriCorrections = .none
    ) -> TodayRing {
        TimelineEvaluator(self, counts: counts, hijri: hijriCorrections, weekStart: weekStart).todayRing(on: today)
    }
}

extension TimelineEvaluator {
    func dailyPace(on day: CalendarDay) -> DailyPace {
        let goal = timeline.uncappedGoal(on: day)
        guard goal.requirement == .cumulativeTotal, goal.sessions.isEmpty, let target = goal.countPolicy.target else {
            return .none
        }
        let past = day > start ? goal.activePeriod.clip(start...day.adding(days: -1)) : nil
        let before = past.map { ledger.total(in: $0, through: $0.upperBound) } ?? 0
        let remaining = max(0, target - before)
        guard let last = goal.activePeriod.lastDay else {
            return DailyPace(pace: nil, remaining: remaining, dueDaysLeft: nil)
        }
        let from = max(day, start)
        let left =
            from > last
            ? 0 : (from...last).filter { timeline.uncappedGoal(on: $0).isDue(on: $0, hijriCorrections: hijri) }.count
        let isDue = goal.isDue(on: day, hijriCorrections: hijri)
        let pace = isDue && left > 0 ? (remaining + Int64(left) - 1) / Int64(left) : nil
        return DailyPace(pace: pace, remaining: remaining, dueDaysLeft: left)
    }

    func todayRing(on today: CalendarDay) -> TodayRing {
        let goal = goal(on: today)
        let none = TodayRing(kind: .none, progress: goal.total(on: today, ledger: ledger), goal: nil)
        if case .periodTotal(let period) = goal.requirement {
            return periodRing(goal, period: period, today: today) ?? none
        }
        guard goal.isDue(on: today, hijriCorrections: hijri) else { return none }
        switch goal.requirement {
        case .perDueDate, .daysPerPeriod:
            return targetRing(goal, today: today)
        case .cumulativeTotal:
            let amount = streakAmount(of: goal.countPolicy, on: today)
            let kind: TodayRing.Kind = goal.countPolicy.streakThreshold == .dailyPace ? .pace : .streakAmount
            return TodayRing(kind: kind, progress: none.progress, goal: amount)
        case .tracker, .periodTotal:
            guard goal.countPolicy.streakThreshold != .anyCount else { return none }
            let amount = streakAmount(of: goal.countPolicy, on: today)
            return none.progress < amount ? TodayRing(kind: .streakAmount, progress: none.progress, goal: amount) : none
        }
    }

    private func targetRing(_ goal: Goal, today: CalendarDay) -> TodayRing {
        guard !goal.sessions.isEmpty else {
            return TodayRing(
                kind: .target, progress: goal.total(on: today, ledger: ledger), goal: goal.countPolicy.target)
        }
        let standings = goal.progress(in: today...today, through: today, ledger: ledger).sessions
        return TodayRing(kind: .target, progress: Self.cappedProgress(standings), goal: Self.combinedTarget(standings))
    }

    /// The week or month so far; `nil` when it has no due day (or today is outside the goal).
    private func periodRing(_ goal: Goal, period: Period, today: CalendarDay) -> TodayRing? {
        guard goal.activePeriod.contains(today),
            let whole = period.window(containing: today, weekStart: weekStart, hijriCorrections: hijri),
            let window = goal.activePeriod.clip(whole), window.contains(where: isDue)
        else { return nil }
        let progress = goal.progress(in: window, through: today, ledger: ledger)
        guard !goal.sessions.isEmpty else {
            return TodayRing(kind: .periodTarget, progress: progress.progress, goal: goal.countPolicy.target)
        }
        return TodayRing(
            kind: .periodTarget, progress: Self.cappedProgress(progress.sessions),
            goal: Self.combinedTarget(progress.sessions))
    }

    /// Each session counts up to its own target.
    private static func cappedProgress(_ standings: [SessionStanding]) -> Int64 {
        standings.reduce(0) { $0.addingSaturating(min($1.progress, $1.target ?? 0)) }
    }

    private static func combinedTarget(_ standings: [SessionStanding]) -> Int64 {
        standings.reduce(0) { $0.addingSaturating($1.target ?? 0) }
    }
}
