import AwradDomain
import Foundation

// contracts/goal-model/v1, slice 4a's rules: timelines, versions, the count log and the lists.
// As in GoalModelFixtures.swift, `given` decodes into domain values and `expect` stays in the
// wire shape, built from the domain's answer to compare.

extension GoalModelFixtures {
    public static func goalVersionOnDay() throws -> [FixtureCase<VersionOnDayGiven, VersionOnDayExpect>] {
        try GoalModelRule.goalVersionOnDay.cases((VersionOnDayGiven.self, VersionOnDayExpect.self))
    }

    public static func goalVersionAdd() throws -> [FixtureCase<VersionAddGiven, VersionsExpect>] {
        try GoalModelRule.goalVersionAdd.cases((VersionAddGiven.self, VersionsExpect.self))
    }

    public static func countAttribution() throws -> [FixtureCase<CountAttributionGiven, CountAttributionExpect>] {
        try GoalModelRule.countAttribution.cases((CountAttributionGiven.self, CountAttributionExpect.self))
    }

    public static func makeUp() throws -> [FixtureCase<MakeUpGiven, MakeUpExpect>] {
        try GoalModelRule.makeUp.cases((MakeUpGiven.self, MakeUpExpect.self))
    }

    public static func excusedDays() throws -> [FixtureCase<ExcuseGiven, ExcuseExpect>] {
        try GoalModelRule.excusedDays.cases((ExcuseGiven.self, ExcuseExpect.self))
    }

    public static func consistency() throws -> [FixtureCase<TimelineOnDay, ConsistencyExpect>] {
        try GoalModelRule.consistency.cases((TimelineOnDay.self, ConsistencyExpect.self))
    }

    public static func dailyPace() throws -> [FixtureCase<TimelineOnDay, DailyPaceExpect>] {
        try GoalModelRule.dailyPace.cases((TimelineOnDay.self, DailyPaceExpect.self))
    }

    public static func todayRing() throws -> [FixtureCase<TimelineOnDay, TodayRingExpect>] {
        try GoalModelRule.todayRing.cases((TimelineOnDay.self, TodayRingExpect.self))
    }

    public static func goalListPlacement() throws -> [FixtureCase<PlacementGiven, PlacementExpect>] {
        try GoalModelRule.goalListPlacement.cases((PlacementGiven.self, PlacementExpect.self))
    }

    public static func goalOrderMerge() throws -> [FixtureCase<OrderMergeGiven, OrderMergeExpect>] {
        try GoalModelRule.goalOrderMerge.cases((OrderMergeGiven.self, OrderMergeExpect.self))
    }
}

// MARK: - Given

/// A goal or timeline (`goal_input`), its counts and the evaluated day.
public struct TimelineOnDay: Decodable, Sendable {
    public let timeline: GoalTimeline
    public let counts: [CountEntry]
    public let date: CalendarDay
    /// Absent for rules that don't use weeks; Monday then, which they never read.
    public let weekStart: WeekStart
    public let hijriCorrections: HijriCorrections

    private enum CodingKeys: String, CodingKey {
        case goal, counts, date, weekStart, hijriCorrections
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        timeline = try values.decode(GoalInputShape.self, forKey: .goal).timeline
        counts = try values.decodeIfPresent([CountShape].self, forKey: .counts)?.map { try $0.entry() } ?? []
        date = try FixtureValue.day(values.decode(String.self, forKey: .date))
        weekStart =
            try values.decodeIfPresent(String.self, forKey: .weekStart).map {
                try FixtureValue.require(WeekStart(rawValue: $0), "week_start \($0)")
            } ?? .monday
        let corrections = try values.decodeIfPresent([CorrectionShape].self, forKey: .hijriCorrections) ?? []
        hijriCorrections = try HijriCorrections(corrections.map(\.correction))
    }
}

/// `make_up`: a timeline on a day, and the first day to report.
public struct MakeUpGiven: Decodable, Sendable {
    public let goal: TimelineOnDay
    public let from: CalendarDay

    private enum CodingKeys: String, CodingKey {
        case from
    }

    public init(from decoder: any Decoder) throws {
        goal = try TimelineOnDay(from: decoder)
        from = try FixtureValue.day(decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .from))
    }
}

/// `excused_days`: a timeline on a day, and the day to excuse or un-excuse.
public struct ExcuseGiven: Decodable, Sendable {
    public enum Action: String, Decodable, Sendable {
        case excuse, unexcuse
    }

    public let goal: TimelineOnDay
    public let day: CalendarDay
    public let action: Action

    private enum CodingKeys: String, CodingKey {
        case day, action
    }

    public init(from decoder: any Decoder) throws {
        goal = try TimelineOnDay(from: decoder)
        let values = try decoder.container(keyedBy: CodingKeys.self)
        day = try FixtureValue.day(values.decode(String.self, forKey: .day))
        action = try values.decode(Action.self, forKey: .action)
    }
}

public struct VersionOnDayGiven: Decodable, Sendable {
    public let document: GoalDocument
    public let date: CalendarDay

    private enum CodingKeys: String, CodingKey {
        case document, date
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        document = try values.decode(DocumentShape.self, forKey: .document).document()
        date = try FixtureValue.day(values.decode(String.self, forKey: .date))
    }
}

public struct VersionAddGiven: Decodable, Sendable {
    public let versions: [GoalVersion]
    public let today: CalendarDay
    public let settings: GoalSettings

    private enum CodingKeys: String, CodingKey {
        case versions, today, settings
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        versions = try values.decode([VersionShape].self, forKey: .versions).map { try $0.version() }
        today = try FixtureValue.day(values.decode(String.self, forKey: .today))
        settings = try values.decode(SettingsShape.self, forKey: .settings).settings()
    }
}

public struct CountAttributionGiven: Decodable, Sendable {
    public struct AttributedGoal: Sendable {
        public let id: AwradID
        public let dhikrID: AwradID
        public let counts: GoalCounts
        public let timeline: GoalTimeline
    }

    private struct GoalShape: Decodable {
        let id: String
        let dhikrId: String
        let counts: String
        let goal: TimelineShape
    }

    public let log: [CountLogEntry]
    public let goals: [AttributedGoal]

    private enum CodingKeys: String, CodingKey {
        case log, goals
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        log = try values.decode([CountLogShape].self, forKey: .log).map { try $0.entry() }
        goals = try values.decode([GoalShape].self, forKey: .goals).map {
            AttributedGoal(
                id: try FixtureValue.id($0.id), dhikrID: try FixtureValue.id($0.dhikrId),
                counts: try FixtureValue.require(GoalCounts(rawValue: $0.counts), "counts \($0.counts)"),
                timeline: try $0.goal.timeline())
        }
    }
}

public struct PlacementGiven: Decodable, Sendable {
    private struct ItemShape: Decodable {
        let id: String
        let goal: GoalInputShape
        let counts: [CountShape]
    }

    public let goals: [GoalListItem]
    public let order: GoalOrder
    public let date: CalendarDay

    private enum CodingKeys: String, CodingKey {
        case goals, order, date
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        goals = try values.decode([ItemShape].self, forKey: .goals).map {
            GoalListItem(
                id: try FixtureValue.id($0.id), timeline: $0.goal.timeline, counts: try $0.counts.map { try $0.entry() }
            )
        }
        order = GoalOrder(goalIDs: try values.decode([String].self, forKey: .order).map(FixtureValue.id))
        date = try FixtureValue.day(values.decode(String.self, forKey: .date))
    }
}

public struct OrderMergeGiven: Decodable, Sendable {
    public let base: GoalOrder
    public let mine: GoalOrder
    public let theirs: GoalOrder

    private enum CodingKeys: String, CodingKey {
        case base, mine, theirs
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        base = try values.decode(GoalOrderShape.self, forKey: .base).order()
        mine = try values.decode(GoalOrderShape.self, forKey: .mine).order()
        theirs = try values.decode(GoalOrderShape.self, forKey: .theirs).order()
    }
}
