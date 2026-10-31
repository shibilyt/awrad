import Foundation

// Rule: streak (contracts/goal-model/v1/fixtures/goal_streak.json).

/// What a streak counts (decision 43), from the version in force today.
public enum StreakUnit: Hashable, Sendable {
    /// Due days: "🔥 15 days".
    case day
    /// Due days of a one-weekday schedule: "🔥 12 Fridays".
    case weekday(Weekday)
    /// Weeks meeting a weekly total or "N days a week".
    case week
    /// Months (Gregorian or Hijri) meeting a monthly requirement.
    case month
    /// Occasions of a yearly schedule whose every due day kept the streak: "🔥 2 Ramadans".
    case occasion

    /// Whether the streak counts periods (weeks or months) rather than days or occasions.
    var isPeriod: Bool { self == .week || self == .month }
}

/// The current streak, its unit and the days still pending make-up ("🔥 15 · make up Mon").
public struct GoalStreak: Hashable, Sendable {
    public var current: Int
    public var unit: StreakUnit
    /// Missed days whose make-up window is still open, oldest first.
    public var pendingMakeUp: [CalendarDay]

    public init(current: Int, unit: StreakUnit, pendingMakeUp: [CalendarDay]) {
        self.current = current
        self.unit = unit
        self.pendingMakeUp = pendingMakeUp
    }
}

extension Goal {
    /// The streak unit of this goal (README.md, Streak units).
    public var streakUnit: StreakUnit {
        if let period = requirement.period { return period == .week ? .week : .month }
        switch schedule {
        case .yearly: return .occasion
        case .weekdays(let weekdays) where weekdays.count == 1: return weekdays.first.map(StreakUnit.weekday) ?? .day
        default: return .day
        }
    }
}

extension GoalTimeline {
    /// The current streak on `today`, counting back in the goal's rhythm (README.md, Streaks).
    ///
    /// Days count when they keep the streak (met, minimum only, made up). Today and days pending
    /// make-up are open: they neither break nor add. The current week, month or occasion is in
    /// progress until it ends unmet; it never breaks the streak while the goal is running. After
    /// the goal's last day, its last day, period or occasion is final. Days that aren't due and
    /// periods that need no days are skipped.
    public func streak(
        on today: CalendarDay, counts: [CountEntry], weekStart: WeekStart, hijriCorrections: HijriCorrections = .none
    ) -> GoalStreak {
        TimelineEvaluator(self, counts: counts, hijri: hijriCorrections, weekStart: weekStart).streak(on: today)
    }
}

/// A week or month of the goal that's due, judged up to today.
struct JudgedPeriod {
    /// The period clipped to the active period.
    let window: ClosedRange<CalendarDay>
    let isInProgress: Bool
    let isMet: Bool
}

/// One occasion (a year's due days of a yearly schedule), judged up to today.
struct JudgedOccasion {
    let isInProgress: Bool
    let isKept: Bool
}

extension TimelineEvaluator {
    func streak(on today: CalendarDay) -> GoalStreak {
        let statuses = dueDayStatuses(through: today)
        return GoalStreak(
            current: currentStreak(on: today, statuses: statuses),
            unit: goal(on: today).streakUnit,
            pendingMakeUp: statuses.filter { $0.status == .pending }.map(\.day)
        )
    }

    /// `statuses` are `dueDayStatuses(through: today)`.
    func currentStreak(on today: CalendarDay, statuses: [DueDayStatus]) -> Int {
        var current = 0
        switch goal(on: today).streakUnit {
        case .week, .month:
            for period in periodsBack(from: today) {
                if period.isMet {
                    current += 1
                } else if !period.isInProgress {
                    break
                }
            }
        case .occasion:
            for occasion in occasionsBack(from: today, statuses: statuses) where !occasion.isInProgress {
                guard occasion.isKept else { break }
                current += 1
            }
        case .day, .weekday:
            for status in statuses.reversed().map(\.status) where !status.isOpen {
                guard status.keepsStreak else { break }
                current += 1
            }
        }
        return current
    }

    /// The goal's due periods, newest first, from the one holding today (or the goal's last day).
    /// A period with no due day, or whose days per period need none, is skipped.
    func periodsBack(from today: CalendarDay) -> some Sequence<JudgedPeriod> {
        let goalToday = goal(on: today)
        let period = goalToday.requirement.period
        var last = goalToday.activePeriod.lastDay.map { min(today, $0) } ?? today
        if period == .hijriMonth { last = min(last, hijri.calendar.range.upperBound) }
        let first = last < start ? nil : period?.window(containing: last, weekStart: weekStart, hijriCorrections: hijri)
        let windows = sequence(state: first) { next -> ClosedRange<CalendarDay>? in
            guard let whole = next else { return nil }
            next = period?.window(
                containing: whole.lowerBound.adding(days: -1), weekStart: weekStart, hijriCorrections: hijri)
            return whole
        }
        return windows.lazy
            .prefix { goalToday.activePeriod.clip($0) != nil }
            .compactMap { goalToday.activePeriod.clip($0).flatMap { judge($0, today: today) } }
    }

    private func judge(_ window: ClosedRange<CalendarDay>, today: CalendarDay) -> JudgedPeriod? {
        guard window.contains(where: isDue) else { return nil }
        let isMet: Bool
        if let tally = daysPerPeriodTally(in: window, through: today) {
            guard tally.required > 0 else { return nil }
            isMet = tally.qualifying >= tally.required
        } else {
            let goal = goal(on: min(window.upperBound, today))
            isMet =
                goal.activePeriod.clip(window).map { goal.progress(in: $0, through: today, ledger: ledger).isMet }
                ?? false
        }
        return JudgedPeriod(window: window, isInProgress: window.upperBound >= today, isMet: isMet)
    }

    /// Qualifying due days (up to `through`) against the days required, for a days-per-period
    /// window judged by the version in force on its last day so far; `nil` for other requirements.
    /// Excused days lower the number; it's capped by the due days the window has.
    func daysPerPeriodTally(
        in window: ClosedRange<CalendarDay>, through: CalendarDay
    ) -> (qualifying: Int, required: Int)? {
        guard case .daysPerPeriod(_, let days) = goal(on: min(window.upperBound, through)).requirement else {
            return nil
        }
        let due = window.filter(isDue)
        let qualifying = due.filter { $0 <= through && meetsDailyTarget(on: $0) }.count
        let excused = window.filter(timeline.excused.contains).count
        return (qualifying, max(0, min(days - excused, due.count)))
    }

    /// The goal's occasions, newest first. The current one is in progress while the goal runs
    /// and it has due days after today, or today or a pending day isn't settled yet.
    func occasionsBack(from today: CalendarDay, statuses: [DueDayStatus]) -> [JudgedOccasion] {
        var groups: [(year: Int?, statuses: [DueDayStatus])] = []
        for status in statuses.reversed() {
            let year = occasionYear(of: status.day)
            if let current = groups.last, current.year == year {
                groups[groups.count - 1].statuses.append(status)
            } else {
                groups.append((year, [status]))
            }
        }
        let running = isRunning(on: today)
        return groups.enumerated().map { index, group in
            let isInProgress =
                index == 0 && running
                && (group.statuses.contains { $0.status.isOpen }
                    || (group.year != nil && nextOccasionYear(after: today) == group.year))
            return JudgedOccasion(isInProgress: isInProgress, isKept: group.statuses.allSatisfy(\.status.keepsStreak))
        }
    }

    private func occasionYear(of day: CalendarDay) -> Int? {
        goal(on: day).schedule.occasionYear(of: day, hijri: hijri.calendar)
    }

    /// The occasion year of the next scheduled, unpaused day within 400 days, if any.
    private func nextOccasionYear(after today: CalendarDay) -> Int? {
        for day in today.adding(days: 1)...today.adding(days: GoalList.horizonDays) {
            let goal = goal(on: day)
            if let last = goal.activePeriod.lastDay, day > last { return nil }
            if goal.isScheduled(on: day, hijriCorrections: hijri), !goal.isPaused(on: day) {
                return occasionYear(of: day)
            }
        }
        return nil
    }
}

extension Goal {
    /// The current streak of a lone goal (`GoalTimeline.streak`).
    public func streak(
        on today: CalendarDay, counts: [CountEntry], weekStart: WeekStart, hijriCorrections: HijriCorrections = .none
    ) -> GoalStreak {
        GoalTimeline(self).streak(on: today, counts: counts, weekStart: weekStart, hijriCorrections: hijriCorrections)
    }
}
