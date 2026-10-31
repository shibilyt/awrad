import Foundation

// The parts of `GoalSettings`: numbers, sessions, requirement, completion and make-up
// (`contracts/goal-model/v1/goal-model.schema.json`).

/// The numbers a goal works against. Counts are whole numbers.
public struct CountPolicy: Hashable, Sendable {
    public var minimum: Int64?
    public var target: Int64?
    /// The cap.
    public var maximum: Int64?
    /// What a day must reach to keep the streak.
    public var streakThreshold: StreakThreshold

    public init(minimum: Int64? = nil, target: Int64?, maximum: Int64? = nil, streakThreshold: StreakThreshold) {
        self.minimum = minimum
        self.target = target
        self.maximum = maximum
        self.streakThreshold = streakThreshold
    }
}

/// Which number a day must reach to keep the streak (README.md, Streaks).
public enum StreakThreshold: Hashable, Sendable {
    /// Any count: 1.
    case anyCount
    case minimum, target, maximum
    /// That day's pace share (`GoalTimeline+Pace`), at least 1. Totals with an end only.
    case dailyPace
    /// A number of its own ("streak counts at 100 a day"), at least 1.
    case amount(Int64)
}

/// A prayer a session can be before or after.
public enum Prayer: String, CaseIterable, Hashable, Sendable {
    case fajr, dhuhr, asr, maghrib, isha
}

/// A local time of day, `HH:MM`.
public struct TimeOfDay: Hashable, Sendable, Comparable, CustomStringConvertible {
    public let hour: Int
    public let minute: Int

    public init?(hour: Int, minute: Int) {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        self.hour = hour
        self.minute = minute
    }

    /// Parses `HH:MM`, the wire format.
    public init?(_ string: String) {
        let parts = string.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, parts.allSatisfy({ $0.count == 2 }), let hour = Int(parts[0]),
            let minute = Int(parts[1])
        else { return nil }
        self.init(hour: hour, minute: minute)
    }

    /// `HH:MM`.
    public var description: String { String(format: "%02d:%02d", hour, minute) }

    /// `HHMM`, as in session IDs.
    var compact: String { String(format: "%02d%02d", hour, minute) }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
    }
}

/// When a session is meant to be counted (decision 10). Kinds only guide: any session can be
/// counted at any time of its day (decision 11).
public enum SessionKind: Hashable, Sendable {
    case anytime
    case beforePrayer(Prayer)
    case afterPrayer(Prayer)
    case atTime(TimeOfDay)
    /// May run past midnight (`from` later than `to`), but can't be empty (`from == to`).
    case between(from: TimeOfDay, to: TimeOfDay)

    /// The session ID this kind derives (README.md, Sessions): `anytime`, `before_fajr`,
    /// `after_fajr`, `at_0630`, `between_2100_2330`. Shared counts match sessions by it.
    public var sessionID: String {
        switch self {
        case .anytime: "anytime"
        case .beforePrayer(let prayer): "before_\(prayer.rawValue)"
        case .afterPrayer(let prayer): "after_\(prayer.rawValue)"
        case .atTime(let time): "at_\(time.compact)"
        case .between(let from, let to): "between_\(from.compact)_\(to.compact)"
        }
    }
}

/// A time-of-day opportunity with its own target (decisions 10 and 47): no minimum, cap or
/// streak threshold of its own, and its streak amount is its target.
public struct GoalSession: Hashable, Sendable, Identifiable {
    /// Derived from the kind (`SessionKind.sessionID`); validity rejects any other.
    public var id: String
    public var kind: SessionKind
    /// `nil` only on a tracker's session, which any count fills.
    public var target: Int64?

    /// A session with the ID its kind derives.
    public init(kind: SessionKind, target: Int64?) {
        self.init(id: kind.sessionID, kind: kind, target: target)
    }

    /// A session as stored or received; validity checks that `id` is the derived one.
    public init(id: String, kind: SessionKind, target: Int64?) {
        self.id = id
        self.kind = kind
        self.target = target
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

    /// The period of a period total or days per period.
    var period: Period? {
        switch self {
        case .periodTotal(let period), .daysPerPeriod(let period, _): period
        case .perDueDate, .cumulativeTotal, .tracker: nil
        }
    }

    /// Whether the goal is judged by day with a daily target (per due date, days per period).
    var hasDailyTarget: Bool {
        switch self {
        case .perDueDate, .daysPerPeriod: true
        case .cumulativeTotal, .periodTotal, .tracker: false
        }
    }
}

/// A week (from the account's week start), a Gregorian month or a Hijri month (with the account's
/// corrections).
public enum Period: String, CaseIterable, Hashable, Sendable {
    case week, month, hijriMonth

    /// The whole period containing `day`, before clipping to an active period; `nil` for a Hijri
    /// month outside the table.
    public func window(
        containing day: CalendarDay,
        weekStart: WeekStart,
        hijriCorrections: HijriCorrections = .none
    ) -> ClosedRange<CalendarDay>? {
        switch self {
        case .week:
            let first = day.adding(days: -day.weekday.daysSince(weekStart.weekday))
            return first...first.adding(days: 6)
        case .month:
            return day.firstDayOfMonth...day.lastDayOfMonth
        case .hijriMonth:
            return hijriCorrections.calendar.month(containing: day)?.days
        }
    }
}

/// When a goal counts as completed. Completion is derived by `Goal.isCompleted`, never stored
/// until the list writes `ended` (`GoalList`).
public enum CompletionPolicy: String, CaseIterable, Hashable, Sendable {
    case never, whenTargetReached, whenDurationEnded
}

/// Make-up (qada, decisions 18, 31 and 48): counts past a later day's own needs fill a missed due
/// day inside its window, up to the fill amount (`GoalTimeline+DayStatus`).
public struct MakeUp: Hashable, Sendable {
    public enum Window: String, CaseIterable, Hashable, Sendable {
        case off
        case nextDay = "next_day"
        case within3Days = "within_3_days"

        /// The practice days after a missed day that can fill it.
        var days: Int {
            switch self {
            case .off: 0
            case .nextDay: 1
            case .within3Days: 3
            }
        }
    }

    public enum Fill: String, CaseIterable, Hashable, Sendable {
        /// Fill to the streak amount (the sentence's default).
        case streak
        /// Fill to the target, or the streak amount if higher.
        case target
    }

    /// No make-up; `fill` is kept when off.
    public static let off = MakeUp(window: .off, fill: .streak)

    public var window: Window
    public var fill: Fill

    public init(window: Window, fill: Fill) {
        self.window = window
        self.fill = fill
    }
}

/// A day's count for the goal (`session == nil`) or for one session, on an effective practice
/// day: what `CountAttribution` makes of the count log.
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
