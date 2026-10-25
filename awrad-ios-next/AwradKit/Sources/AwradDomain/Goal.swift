import Foundation

/// A single measurable objective attached to one dhikr or tracked amal (CONTEXT.md, Goal language).
///
/// The rule-bearing fields mirror `contracts/goal-model/v1/goal-model.schema.json`. The rules
/// themselves live in one file each: `Goal+IsDue`, `Goal+RequirementStanding`,
/// `Goal+DaysPerPeriod`, `Goal+Completion`, `Goal+Streak`, plus `EffectivePracticeDay`.
///
/// Values aren't validated here: rejecting empty weekday sets, `every < 1` or a missing target is
/// the boundary's job (slice 3). The rules stay total on invalid values: they're never due or met.
public struct Goal: Hashable, Sendable {
    public var id: AwradID
    public var dhikrCatalogKey: String
    public var schedule: Schedule
    public var activePeriod: ActivePeriod
    public var paused: [PausedRange]
    /// The goal's own numbers. With sessions, each session's count policy applies instead.
    public var countPolicy: CountPolicy
    public var sessions: [GoalSession]
    public var requirement: Requirement
    public var completion: CompletionPolicy

    public init(
        id: AwradID,
        dhikrCatalogKey: String,
        schedule: Schedule,
        activePeriod: ActivePeriod,
        paused: [PausedRange] = [],
        countPolicy: CountPolicy,
        sessions: [GoalSession] = [],
        requirement: Requirement,
        completion: CompletionPolicy = .never
    ) {
        self.id = id
        self.dhikrCatalogKey = dhikrCatalogKey
        self.schedule = schedule
        self.activePeriod = activePeriod
        self.paused = paused
        self.countPolicy = countPolicy
        self.sessions = sessions
        self.requirement = requirement
        self.completion = completion
    }
}

/// Which days a goal is due (Gregorian kinds; Hijri, yearly and seasons follow in slice 1b).
public enum Schedule: Hashable, Sendable {
    case everyDay
    case weekdays(Set<Weekday>)
    /// Every `every` days counted from `anchor`, or from the start date when `anchor` is `nil`.
    case everyNDays(Int, anchor: CalendarDay?)
    /// Days of the month (1...31). A day past the month's end falls on its last day.
    case monthDays(Set<Int>)
    case specificDates(Set<CalendarDay>)
    /// No repeating pattern: due every day of the active period until completed.
    case oneTime
}

/// The span a goal can be due in. Both ends are inclusive.
public struct ActivePeriod: Hashable, Sendable {
    public var start: CalendarDay
    public var end: CalendarDay?
    /// Days from the start, so the last day is start + N − 1. Must be at least 1.
    public var durationDays: Int?

    public init(start: CalendarDay, end: CalendarDay? = nil, durationDays: Int? = nil) {
        self.start = start
        self.end = end
        self.durationDays = durationDays
    }

    /// The earlier of the end date and the duration's last day; `nil` when open-ended.
    public var lastDay: CalendarDay? {
        let durationEnd = durationDays.map { start.adding(days: max($0, 0) - 1) }
        switch (end, durationEnd) {
        case (let end?, let durationEnd?): return min(end, durationEnd)
        case (let end, let durationEnd): return end ?? durationEnd
        }
    }

    public func contains(_ day: CalendarDay) -> Bool {
        day >= start && lastDay.map { day <= $0 } ?? true
    }

    /// `window` clipped to the active period; `nil` when they don't overlap.
    func clip(_ window: ClosedRange<CalendarDay>) -> ClosedRange<CalendarDay>? {
        let from = max(window.lowerBound, start)
        let to = lastDay.map { min(window.upperBound, $0) } ?? window.upperBound
        return from <= to ? from...to : nil
    }
}

/// Days the user suspended the goal. `to` is inclusive; `nil` means still paused.
public struct PausedRange: Hashable, Sendable {
    public var from: CalendarDay
    public var to: CalendarDay?

    public init(from: CalendarDay, to: CalendarDay?) {
        self.from = from
        self.to = to
    }

    public func contains(_ day: CalendarDay) -> Bool {
        day >= from && to.map { day <= $0 } ?? true
    }
}

/// The numbers a goal or session works against. Counts are whole numbers.
public struct CountPolicy: Hashable, Sendable {
    public var minimum: Int64?
    public var target: Int64?
    /// The cap.
    public var maximum: Int64?
    /// Which number a day must reach to count toward the streak.
    public var streakThreshold: CountThreshold

    public init(minimum: Int64? = nil, target: Int64?, maximum: Int64? = nil, streakThreshold: CountThreshold) {
        self.minimum = minimum
        self.target = target
        self.maximum = maximum
        self.streakThreshold = streakThreshold
    }

    /// Whether `count` reaches `threshold`. A threshold whose number isn't set can never be met.
    public func isMet(by count: Int64, at threshold: CountThreshold) -> Bool {
        switch threshold {
        case .anyCount: count > 0
        case .minimum: minimum.map { count >= $0 } ?? false
        case .target: target.map { count >= $0 } ?? false
        case .maximum: maximum.map { count >= $0 } ?? false
        }
    }
}

/// One of a count policy's levels.
public enum CountThreshold: String, CaseIterable, Hashable, Sendable {
    case anyCount, minimum, target, maximum
}

/// A time-of-day opportunity (after Fajr, at 18:00, …) with its own count policy.
public struct GoalSession: Hashable, Sendable, Identifiable {
    /// Stable within the goal, such as `fajr`.
    public var id: String
    public var countPolicy: CountPolicy

    public init(id: String, countPolicy: CountPolicy) {
        self.id = id
        self.countPolicy = countPolicy
    }
}

/// The rule that decides whether a goal is met within a window. Totals use the count policy's
/// target as the total; days per period uses it as the daily target.
public enum Requirement: Hashable, Sendable {
    case perDueDate
    case cumulativeTotal
    case periodTotal(Period)
    /// `days` qualifying days per period (a qualifying day is a due day meeting the daily target).
    case daysPerPeriod(Period, days: Int)
    /// No target: any count is progress.
    case tracker
}

/// A week (from the account's week start) or a Gregorian month.
public enum Period: String, CaseIterable, Hashable, Sendable {
    case week, month

    /// The whole period containing `day`, before clipping to an active period.
    public func window(containing day: CalendarDay, weekStart: WeekStart) -> ClosedRange<CalendarDay> {
        switch self {
        case .week:
            let first = day.adding(days: -day.weekday.daysSince(weekStart.weekday))
            return first...first.adding(days: 6)
        case .month:
            return day.firstDayOfMonth...day.lastDayOfMonth
        }
    }
}

/// When a goal counts as completed. Completion is derived by `Goal.isCompleted`, never stored.
public enum CompletionPolicy: String, CaseIterable, Hashable, Sendable {
    case never, whenTargetReached, whenDurationEnded
}

/// A day's count for the goal (`session == nil`) or for one session, on an effective practice day.
public struct CountEntry: Hashable, Sendable {
    public var day: CalendarDay
    public var session: String?
    public var count: Int64

    public init(day: CalendarDay, session: String? = nil, count: Int64) {
        self.day = day
        self.session = session
        self.count = count
    }
}

/// Port: goal persistence. Adapters own storage and sync bookkeeping.
public protocol GoalRepository: Sendable {
    func add(_ goal: Goal) async throws
    func count() async throws -> Int
}
