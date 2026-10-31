import Foundation

// A goal's whole life (`$defs/goal_timeline`, `$defs/goal_document`), the user's goal order and
// the count log (`contracts/goal-model/v1/README.md`, The goal document).

/// Settings in force from `from` (an effective practice day) until the next version's `from`.
public struct GoalVersion: Hashable, Sendable {
    public var from: CalendarDay
    public var settings: GoalSettings

    public init(from: CalendarDay, settings: GoalSettings) {
        self.from = from
        self.settings = settings
    }
}

/// When and why a goal finished. `on` is its last day, inclusive.
public struct GoalEnding: Hashable, Sendable {
    public enum Reason: String, CaseIterable, Hashable, Sendable {
        /// End goal.
        case user
        /// A cumulative total reached.
        case completed
        /// Its active period ran out, or no scheduled day is left.
        case date
        /// A different schedule or requirement type started a new goal.
        case structuralEdit = "structural_edit"
        /// Its custom dhikr was deleted.
        case dhikrDeleted = "dhikr_deleted"
    }

    public var on: CalendarDay
    public var reason: Reason

    public init(on: CalendarDay, reason: Reason) {
        self.on = on
        self.reason = reason
    }
}

/// Everything about a goal's days: every dated version, pauses, excused days and its end. The
/// cross-day rules (`GoalTimeline+…`) evaluate each day with the version in force that day.
///
/// Only a valid timeline exists: versions oldest first with strictly increasing `from`, the first
/// on `createdOn`, and equal structural fields (`GoalStructure`); each version's settings are
/// valid by construction.
public struct GoalTimeline: Hashable, Sendable {
    public let createdOn: CalendarDay
    /// 1 to 100 versions, oldest first.
    public let versions: [GoalVersion]
    public let paused: [PausedRange]
    public let excused: [CalendarDay]
    public let ended: GoalEnding?

    public init(
        createdOn: CalendarDay,
        versions: [GoalVersion],
        paused: [PausedRange] = [],
        excused: [CalendarDay] = [],
        ended: GoalEnding? = nil
    ) throws(GoalValidationError) {
        let codes = Self.validationCodes(
            createdOn: createdOn, versions: versions.map { ($0.from, GoalStructure($0.settings)) })
        guard codes.isEmpty else { throw GoalValidationError(codes) }
        self.createdOn = createdOn
        self.versions = versions
        self.paused = paused
        self.excused = excused
        self.ended = ended
    }

    /// The same timeline, ended. Ending never makes a timeline invalid.
    public func ending(_ ending: GoalEnding) -> GoalTimeline {
        GoalTimeline(copying: self, ended: ending)
    }

    private init(copying other: GoalTimeline, ended: GoalEnding?) {
        createdOn = other.createdOn
        versions = other.versions
        paused = other.paused
        excused = other.excused
        self.ended = ended
    }

    /// The timeline a lone goal stands for: one version from its start date, never ended.
    public init(_ goal: Goal) {
        createdOn = goal.activePeriod.start
        versions = [GoalVersion(from: goal.activePeriod.start, settings: goal.settings)]
        paused = goal.paused
        excused = goal.excused
        ended = nil
    }
}

/// The fields every version of one goal shares (README.md, Dated versions): changing one ends
/// the goal and starts a new one.
public struct GoalStructure: Hashable, Sendable {
    /// The schedule kind, and a yearly schedule's calendar.
    public let schedule: String
    /// The requirement type, and its period.
    public let requirement: String
    public let start: CalendarDay

    public init(schedule: Schedule, requirement: Requirement, start: CalendarDay) {
        self.schedule = Self.name(of: schedule)
        let type: String =
            switch requirement {
            case .perDueDate: "per_due_date"
            case .cumulativeTotal: "cumulative_total"
            case .periodTotal: "period_total"
            case .daysPerPeriod: "days_per_period"
            case .tracker: "tracker"
            }
        self.requirement = requirement.period.map { "\(type).\($0.rawValue)" } ?? type
        self.start = start
    }

    init(_ settings: GoalSettings) {
        self.init(schedule: settings.schedule, requirement: settings.requirement, start: settings.activePeriod.start)
    }

    private static func name(of schedule: Schedule) -> String {
        switch schedule {
        case .everyDay: "every_day"
        case .weekdays: "weekdays"
        case .everyNDays: "every_n_days"
        case .monthDays: "month_days"
        case .specificDates: "specific_dates"
        case .oneTime: "one_time"
        case .hijriMonthDays: "hijri_month_days"
        case .yearly(let calendar, _): "yearly.\(calendar.rawValue)"
        }
    }
}

/// Which count-log entries fill a goal (`CountAttribution`). Set at creation, never changed.
public enum GoalCounts: String, CaseIterable, Hashable, Sendable {
    /// Every entry of its dhikr made without a goal, wherever it was made.
    case shared
    /// Only entries made in this goal; they fill no other.
    case dedicated
}

/// The dhikr's label when the goal was last saved (decision 37), shown only once the dhikr is gone.
public struct DhikrSnapshot: Hashable, Sendable {
    /// en, ar and ml; at least one is text.
    public var title: LanguageTexts
    public var arabic: String
    public var kind: DhikrKind

    public init(title: LanguageTexts, arabic: String, kind: DhikrKind) {
        self.title = title
        self.arabic = arabic
        self.kind = kind
    }
}

/// The `goal` sync entity's document (`$defs/goal_document`; its entity ID is a UUIDv7).
public struct GoalDocument: Hashable, Sendable {
    /// A built-in dhikr's catalog ID or a custom dhikr's entity ID. Never changes.
    public var dhikrID: AwradID
    public var dhikrSnapshot: DhikrSnapshot
    /// The user's own name, or `nil` to show the dhikr's title. Not versioned.
    public var name: String?
    public var counts: GoalCounts
    public var timeline: GoalTimeline

    public init(
        dhikrID: AwradID, dhikrSnapshot: DhikrSnapshot, name: String?, counts: GoalCounts, timeline: GoalTimeline
    ) {
        self.dhikrID = dhikrID
        self.dhikrSnapshot = dhikrSnapshot
        self.name = name
        self.counts = counts
        self.timeline = timeline
    }
}

/// The `goal_order` sync entity's document: the user's order of My Goals (decision 25). One per
/// account, written only when the user reorders.
public struct GoalOrder: Hashable, Sendable {
    public var goalIDs: [AwradID]

    public init(goalIDs: [AwradID]) {
        self.goalIDs = goalIDs
    }
}

/// One entry of a profile's append-only count log (`$defs/count_log_entry`). Counts belong to
/// the dhikr: `goalID` is set only for a count made in a dedicated goal.
public struct CountLogEntry: Hashable, Sendable, Identifiable {
    /// A UUIDv7 made where the count was made.
    public var id: AwradID
    public var dhikrID: AwradID
    public var practiceDay: CalendarDay
    public var sessionID: String?
    public var goalID: AwradID?
    /// Never 0; negative for an adjustment or an undo.
    public var amount: Int64
    public var countedAt: Date

    public init(
        id: AwradID, dhikrID: AwradID, practiceDay: CalendarDay, sessionID: String? = nil, goalID: AwradID? = nil,
        amount: Int64, countedAt: Date
    ) {
        self.id = id
        self.dhikrID = dhikrID
        self.practiceDay = practiceDay
        self.sessionID = sessionID
        self.goalID = goalID
        self.amount = amount
        self.countedAt = countedAt
    }
}

/// Port: goal persistence. Adapters own storage and sync bookkeeping.
public protocol GoalRepository: Sendable {
    /// Stores a goal document under its entity ID.
    func add(_ document: GoalDocument, id: AwradID) async throws
    func count() async throws -> Int
}
