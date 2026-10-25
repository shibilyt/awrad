import AwradDomain
import Foundation

// The goal shape of `contracts/goal-model/v1/goal-model.schema.json`, decoded and turned into
// domain values. Fixture-only: the API and persistence codecs arrive in slice 3.

struct GoalShape: Decodable {
    struct ScheduleShape: Decodable {
        let kind: String
        let weekdays: [String]?
        let every: Int?
        let anchorDate: String?
        let days: [Int]?
        let dates: [String]?
    }

    struct ActivePeriodShape: Decodable {
        let startDate: String
        let endDate: String?
        let durationDays: Int?
    }

    struct PausedShape: Decodable {
        let from: String
        let to: String?
    }

    struct CountPolicyShape: Decodable {
        let minimum: Int64?
        let target: Int64?
        let maximum: Int64?
        let streakThreshold: String
    }

    struct SessionShape: Decodable {
        let id: String
        let countPolicy: CountPolicyShape
    }

    struct RequirementShape: Decodable {
        let type: String
        let period: String?
        let days: Int?
    }

    let schedule: ScheduleShape
    let activePeriod: ActivePeriodShape
    let paused: [PausedShape]
    let countPolicy: CountPolicyShape
    let sessions: [SessionShape]
    let requirement: RequirementShape
    let completion: String

    /// Fixtures carry no identity, so every fixture goal gets the same placeholder one.
    static let fixtureID = AwradID(UUID(uuid: (0, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, 0)))

    func goal() throws -> Goal {
        Goal(
            id: Self.fixtureID,
            dhikrCatalogKey: "fixture",
            schedule: try schedule.domain(),
            activePeriod: ActivePeriod(
                start: try FixtureValue.day(activePeriod.startDate),
                end: try activePeriod.endDate.map(FixtureValue.day),
                durationDays: activePeriod.durationDays
            ),
            paused: try paused.map {
                PausedRange(from: try FixtureValue.day($0.from), to: try $0.to.map(FixtureValue.day))
            },
            countPolicy: try countPolicy.domain(),
            sessions: try sessions.map { GoalSession(id: $0.id, countPolicy: try $0.countPolicy.domain()) },
            requirement: try requirement.domain(),
            completion: try FixtureValue.require(
                CompletionPolicy(rawValue: FixtureValue.camelCase(completion)), "completion \(completion)")
        )
    }
}

extension GoalShape.ScheduleShape {
    func domain() throws -> Schedule {
        switch kind {
        case "every_day":
            return .everyDay
        case "weekdays":
            let names = try FixtureValue.require(weekdays, "weekdays")
            return .weekdays(Set(try names.map { try FixtureValue.require(Weekday(rawValue: $0), "weekday \($0)") }))
        case "every_n_days":
            return .everyNDays(try FixtureValue.require(every, "every"), anchor: try anchorDate.map(FixtureValue.day))
        case "month_days":
            return .monthDays(Set(try FixtureValue.require(days, "days")))
        case "specific_dates":
            return .specificDates(Set(try FixtureValue.require(dates, "dates").map(FixtureValue.day)))
        case "one_time":
            return .oneTime
        default:
            throw FixtureValue.Invalid(value: "schedule kind \(kind)")
        }
    }
}

extension GoalShape.CountPolicyShape {
    func domain() throws -> CountPolicy {
        CountPolicy(
            minimum: minimum,
            target: target,
            maximum: maximum,
            streakThreshold: try FixtureValue.require(
                CountThreshold(rawValue: FixtureValue.camelCase(streakThreshold)), "streak_threshold \(streakThreshold)"
            )
        )
    }
}

extension GoalShape.RequirementShape {
    func domain() throws -> Requirement {
        switch type {
        case "per_due_date": return .perDueDate
        case "cumulative_total": return .cumulativeTotal
        case "tracker": return .tracker
        case "period_total": return .periodTotal(try domainPeriod())
        case "days_per_period": return .daysPerPeriod(try domainPeriod(), days: try FixtureValue.require(days, "days"))
        default: throw FixtureValue.Invalid(value: "requirement type \(type)")
        }
    }

    private func domainPeriod() throws -> Period {
        let name = try FixtureValue.require(period, "period")
        return try FixtureValue.require(Period(rawValue: name), "period \(name)")
    }
}

struct CountShape: Decodable {
    let date: String
    let session: String?
    let count: Int64

    func entry() throws -> CountEntry {
        CountEntry(day: try FixtureValue.day(date), session: session, count: count)
    }
}

/// Conversions between fixture strings and domain values.
enum FixtureValue {
    struct Invalid: Error, CustomStringConvertible {
        let value: String
        var description: String { "invalid or missing \(value)" }
    }

    static func require<Value>(_ value: Value?, _ name: @autoclosure () -> String) throws -> Value {
        guard let value else { throw Invalid(value: name()) }
        return value
    }

    static func day(_ string: String) throws -> CalendarDay {
        try require(CalendarDay(string), "date \(string)")
    }

    static func instant(_ string: String) throws -> Date {
        do {
            return try Date.ISO8601FormatStyle().parse(string)
        } catch {
            throw Invalid(value: "instant \(string)")
        }
    }

    /// `when_target_reached` → `whenTargetReached`, for the domain's raw values.
    static func camelCase(_ snake: String) -> String {
        let words = snake.split(separator: "_")
        return words.enumerated().map { $0.offset == 0 ? String($0.element) : $0.element.capitalized }.joined()
    }

    static func status(_ status: RequirementStanding.Status) -> String {
        switch status {
        case .met: "met"
        case .notMet: "not_met"
        case .notDue: "not_due"
        }
    }
}
