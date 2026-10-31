import Foundation

/// What a goal rule evaluates on one day (`$defs/goal` of `contracts/goal-model/v1`): one
/// version's settings plus the goal's pauses and excused days. A goal's whole life is a
/// `GoalTimeline` (`GoalDocument` adds the dhikr, name and counts); `timeline.goal(on:)` resolves it
/// into the `Goal` in force on a day, and a lone `Goal` stands for a timeline of one version.
///
/// The rules live in one file each: `Goal+Validity`, `Goal+IsDue`, `Goal+RequirementStanding`,
/// `Goal+DaysPerPeriod`, `Goal+Completion`, then the timeline rules (`GoalTimeline+…`), `GoalList`
/// and `CountAttribution`, plus `EffectivePracticeDay`.
///
/// Every `Goal` is valid: its settings are (`GoalSettings` throws `GoalValidationError`), and the
/// properties are read-only, so no rule ever sees an invalid goal. Structural limits the schema
/// enforces (an empty weekday set, `every < 1`) are the boundary's job; the rules stay total on
/// them: never due or met.
public struct Goal: Hashable, Sendable {
    public let settings: GoalSettings
    /// Days the user suspended the goal. Not versioned.
    public let paused: [PausedRange]
    /// Past missed days the user excused (`GoalTimeline+Excuse`), skipped like paused days. Not
    /// versioned.
    public let excused: [CalendarDay]

    public init(settings: GoalSettings, paused: [PausedRange] = [], excused: [CalendarDay] = []) {
        self.settings = settings
        self.paused = paused
        self.excused = excused
    }

    /// Builds the settings and the goal, or throws every reason the settings are invalid.
    public init(
        schedule: Schedule,
        activePeriod: ActivePeriod,
        paused: [PausedRange] = [],
        excused: [CalendarDay] = [],
        countPolicy: CountPolicy,
        sessions: [GoalSession] = [],
        requirement: Requirement,
        completion: CompletionPolicy = .never,
        makeUp: MakeUp = .off
    ) throws(GoalValidationError) {
        let settings = try GoalSettings(
            schedule: schedule, activePeriod: activePeriod, countPolicy: countPolicy, sessions: sessions,
            requirement: requirement, completion: completion, makeUp: makeUp)
        self.init(settings: settings, paused: paused, excused: excused)
    }

    public var schedule: Schedule { settings.schedule }
    public var activePeriod: ActivePeriod { settings.activePeriod }
    /// The goal's own numbers. With sessions, each session's target applies instead.
    public var countPolicy: CountPolicy { settings.countPolicy }
    public var sessions: [GoalSession] { settings.sessions }
    public var requirement: Requirement { settings.requirement }
    public var completion: CompletionPolicy { settings.completion }
    public var makeUp: MakeUp { settings.makeUp }

    func isPaused(on day: CalendarDay) -> Bool {
        paused.contains { $0.contains(day) }
    }

    func isExcused(on day: CalendarDay) -> Bool {
        excused.contains(day)
    }
}

/// The settings a dated version holds (`$defs/goal_settings`): everything a rule reads except
/// pauses and excused days. The initializer throws every reason they'd be invalid, so only valid
/// settings exist.
public struct GoalSettings: Hashable, Sendable {
    public let schedule: Schedule
    public let activePeriod: ActivePeriod
    public let countPolicy: CountPolicy
    public let sessions: [GoalSession]
    public let requirement: Requirement
    public let completion: CompletionPolicy
    public let makeUp: MakeUp

    public init(
        schedule: Schedule,
        activePeriod: ActivePeriod,
        countPolicy: CountPolicy,
        sessions: [GoalSession] = [],
        requirement: Requirement,
        completion: CompletionPolicy = .never,
        makeUp: MakeUp = .off
    ) throws(GoalValidationError) {
        let codes = Self.validationCodes(
            activePeriod: activePeriod, countPolicy: countPolicy, sessions: sessions,
            requirement: requirement, makeUp: makeUp)
        guard codes.isEmpty else { throw GoalValidationError(codes) }
        self.schedule = schedule
        self.activePeriod = activePeriod
        self.countPolicy = countPolicy
        self.sessions = sessions
        self.requirement = requirement
        self.completion = completion
        self.makeUp = makeUp
    }

    /// The same settings with the active period ending on `day` (an ended goal's last day). Still
    /// valid: an end date never breaks a rule, and it replaces any number of days.
    func ending(on day: CalendarDay) -> GoalSettings {
        GoalSettings(copying: self, activePeriod: ActivePeriod(start: activePeriod.start, end: day))
    }

    private init(copying other: GoalSettings, activePeriod: ActivePeriod) {
        schedule = other.schedule
        self.activePeriod = activePeriod
        countPolicy = other.countPolicy
        sessions = other.sessions
        requirement = other.requirement
        completion = other.completion
        makeUp = other.makeUp
    }
}

/// Which days a goal is due. Seasons (Ramadan, white days…) aren't a kind: they're presets that
/// fill in `hijriMonthDays` or `yearly` (`contracts/goal-presets/v1`).
public enum Schedule: Hashable, Sendable {
    /// Also a total with no rhythm ("70,000 in total"): due every day of its active period.
    case everyDay
    case weekdays(Set<Weekday>)
    /// Every `every` days counted from `anchor`, or from the start date when `anchor` is `nil`.
    case everyNDays(Int, anchor: CalendarDay?)
    /// Days of the month (1...31). A day past the month's end falls on its last day.
    case monthDays(Set<Int>)
    case specificDates(Set<CalendarDay>)
    /// Kept from slice 1 and evaluated like `everyDay`; the sentence never writes it.
    case oneTime
    /// Days of the Hijri month (1...30). Day 30 falls on day 29 in a 29-day month.
    case hijriMonthDays(Set<Int>)
    /// Inclusive month-day ranges every year, in the Gregorian or Hijri calendar.
    case yearly(YearlyCalendar, ranges: [YearlyRange])
}

/// The calendar a yearly schedule's dates are in.
public enum YearlyCalendar: String, CaseIterable, Hashable, Sendable {
    case gregorian, hijri
}

/// A month and day in a yearly schedule. A day past the month's end falls on its last day
/// (29 February in a common year, Hijri day 30 in a 29-day month).
public struct MonthDay: Hashable, Sendable, Comparable {
    public var month: Int
    public var day: Int

    public init(month: Int, day: Int) {
        self.month = month
        self.day = day
    }

    public static func < (lhs: MonthDay, rhs: MonthDay) -> Bool {
        (lhs.month, lhs.day) < (rhs.month, rhs.day)
    }
}

/// An inclusive range of a yearly schedule. When `end` comes before `start`, it runs over the
/// year end; a single day has `start == end`.
public struct YearlyRange: Hashable, Sendable {
    public var start: MonthDay
    public var end: MonthDay

    public init(start: MonthDay, end: MonthDay) {
        self.start = start
        self.end = end
    }

    /// Whether the range runs over the year end.
    var wrapsYearEnd: Bool { end < start }
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

    /// Whether the period has a last day (an end date or a number of days).
    var hasEnd: Bool { end != nil || durationDays != nil }

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
