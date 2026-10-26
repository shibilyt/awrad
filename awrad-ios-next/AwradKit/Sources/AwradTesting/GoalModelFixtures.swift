import AwradDomain
import Foundation

// contracts/goal-model/v1: the rules iOS implements, and each rule's `given` and `expect` shapes.
// `given` decodes into domain values; `expect` stays in the wire shape (snake_case status names,
// `YYYY-MM-DD` days), and each `expect` type can be built from the domain's answer to compare.

/// Every goal-model rule iOS implements. The runner fails if any has no fixture file or no cases.
public enum GoalModelRule: String, CaseIterable, Sendable {
    case effectivePracticeDay = "effective_practice_day"
    case goalIsDue = "goal_is_due"
    case requirementStanding = "requirement_standing"
    case daysPerPeriod = "days_per_period"
    case goalCompletion = "goal_completion"
    case goalStreak = "goal_streak"
    case goalValidity = "goal_validity"

    /// `contracts/goal-model/v1/fixtures/<rule>.json` in this repository.
    public func fixtureFile(from filePath: String = #filePath) throws -> URL {
        try FixtureLoader.fixturesDirectory(model: "goal-model", from: filePath).appending(path: "\(rawValue).json")
    }

    public func cases<Given: Decodable & Sendable, Expect: Decodable & Sendable>(
        _ shape: (Given.Type, Expect.Type)
    ) throws -> [FixtureCase<Given, Expect>] {
        try FixtureLoader.load(fixtureFile(), rule: rawValue, as: shape)
    }
}

/// Typed case lists, one per rule, for `@Test(arguments:)`.
public enum GoalModelFixtures {
    public static func effectivePracticeDay() throws -> [FixtureCase<EffectiveDayGiven, DateExpect>] {
        try GoalModelRule.effectivePracticeDay.cases((EffectiveDayGiven.self, DateExpect.self))
    }

    public static func goalIsDue() throws -> [FixtureCase<GoalOnDay, DueExpect>] {
        try GoalModelRule.goalIsDue.cases((GoalOnDay.self, DueExpect.self))
    }

    public static func requirementStanding() throws -> [FixtureCase<GoalOnDay, StandingExpect>] {
        try GoalModelRule.requirementStanding.cases((GoalOnDay.self, StandingExpect.self))
    }

    public static func daysPerPeriod() throws -> [FixtureCase<GoalOnDay, DaysPerPeriodExpect>] {
        try GoalModelRule.daysPerPeriod.cases((GoalOnDay.self, DaysPerPeriodExpect.self))
    }

    public static func goalCompletion() throws -> [FixtureCase<GoalOnDay, CompletionExpect>] {
        try GoalModelRule.goalCompletion.cases((GoalOnDay.self, CompletionExpect.self))
    }

    public static func goalStreak() throws -> [FixtureCase<GoalOnDay, StreakExpect>] {
        try GoalModelRule.goalStreak.cases((GoalOnDay.self, StreakExpect.self))
    }

    public static func goalValidity() throws -> [FixtureCase<GoalValidityGiven, ValidityExpect>] {
        try GoalModelRule.goalValidity.cases((GoalValidityGiven.self, ValidityExpect.self))
    }
}

// MARK: - Given

public struct EffectiveDayGiven: Decodable, Sendable {
    public let instant: Date
    public let timeZone: TimeZone
    public let dayReset: DayReset
    public let maghrib: Date?

    private enum CodingKeys: String, CodingKey {
        case instant, timezone, dayReset, maghrib
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        instant = try FixtureValue.instant(values.decode(String.self, forKey: .instant))
        let zone = try values.decode(String.self, forKey: .timezone)
        timeZone = try FixtureValue.require(TimeZone(identifier: zone), "timezone \(zone)")
        let reset = try values.decode(String.self, forKey: .dayReset)
        dayReset = try FixtureValue.require(DayReset(rawValue: reset), "day_reset \(reset)")
        maghrib = try values.decode(String?.self, forKey: .maghrib).map(FixtureValue.instant)
    }
}

/// A goal, its counts and the evaluated day. `counts` and `weekStart` are absent in some rules.
public struct GoalOnDay: Decodable, Sendable {
    public let goal: Goal
    public let counts: [CountEntry]
    public let date: CalendarDay
    /// Absent for rules that don't use weeks (is due, completion).
    public let weekStart: WeekStart?
    /// The account's Hijri corrections; absent means none. Invalid ones fail the case.
    public let hijriCorrections: HijriCorrections

    private enum CodingKeys: String, CodingKey {
        case goal, counts, date, weekStart, hijriCorrections
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        goal = try values.decode(GoalShape.self, forKey: .goal).goal()
        counts = try values.decodeIfPresent([CountShape].self, forKey: .counts)?.map { try $0.entry() } ?? []
        date = try FixtureValue.day(values.decode(String.self, forKey: .date))
        weekStart = try values.decodeIfPresent(String.self, forKey: .weekStart).map {
            try FixtureValue.require(WeekStart(rawValue: $0), "week_start \($0)")
        }
        let corrections = try values.decodeIfPresent([CorrectionShape].self, forKey: .hijriCorrections) ?? []
        hijriCorrections = try HijriCorrections(corrections.map(\.correction))
    }
}

/// A `goal_shape` that may be invalid: the only `given` that doesn't require a valid goal. The
/// shape decodes, and `construction` is what `Goal`'s validating initializer made of it.
public struct GoalValidityGiven: Decodable, Sendable {
    public let construction: Result<Goal, GoalValidationError>

    private enum CodingKeys: String, CodingKey {
        case goal
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        construction = try values.decode(GoalShape.self, forKey: .goal).construct()
    }
}

// MARK: - Expect

public struct DateExpect: Decodable, Equatable, Sendable {
    public let date: String

    public init(_ day: CalendarDay) { date = day.description }
}

public struct DueExpect: Decodable, Equatable, Sendable {
    public let due: Bool

    public init(due: Bool) { self.due = due }
}

public struct WindowExpect: Decodable, Equatable, Sendable, CustomStringConvertible {
    public let from: String
    public let to: String

    public init(_ window: ClosedRange<CalendarDay>) {
        from = window.lowerBound.description
        to = window.upperBound.description
    }

    public var description: String { "\(from)…\(to)" }
}

public struct StandingExpect: Decodable, Equatable, Sendable {
    public struct Session: Decodable, Equatable, Sendable {
        public let id: String
        public let progress: Int64
        public let target: Int64?
        public let status: String
    }

    public let status: String
    public let window: WindowExpect
    public let progress: Int64
    public let target: Int64?
    public let sessions: [Session]

    public init(_ standing: RequirementStanding) {
        status = FixtureValue.status(standing.status)
        window = WindowExpect(standing.window)
        progress = standing.progress
        target = standing.target
        sessions = standing.sessions.map {
            Session(id: $0.id, progress: $0.progress, target: $0.target, status: $0.isMet ? "met" : "not_met")
        }
    }
}

public struct DaysPerPeriodExpect: Decodable, Equatable, Sendable {
    public let status: String
    public let window: WindowExpect
    public let qualifyingDays: Int
    public let requiredDays: Int

    public init(_ standing: DaysPerPeriodStanding) {
        status = FixtureValue.status(standing.status)
        window = WindowExpect(standing.window)
        qualifyingDays = standing.qualifyingDays
        requiredDays = standing.requiredDays
    }
}

public struct CompletionExpect: Decodable, Equatable, Sendable {
    public let completed: Bool

    public init(completed: Bool) { self.completed = completed }
}

public struct StreakExpect: Decodable, Equatable, Sendable {
    public let current: Int

    public init(current: Int) { self.current = current }
}

public struct ValidityExpect: Decodable, Equatable, Sendable {
    public let valid: Bool
    /// Error codes, in the order the domain reports them (the contract's is alphabetical).
    public let errors: [String]

    public init(_ construction: Result<Goal, GoalValidationError>) {
        switch construction {
        case .success: self.init(errors: [])
        case .failure(let error): self.init(errors: error.codes.map(\.rawValue))
        }
    }

    /// Valid exactly when `errors` is empty.
    public init(errors: [String]) {
        valid = errors.isEmpty
        self.errors = errors
    }
}
