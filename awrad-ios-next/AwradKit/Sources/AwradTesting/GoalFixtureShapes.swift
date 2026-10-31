import AwradDomain
import Foundation

// The settings and goal shapes of `contracts/goal-model/v1/goal-model.schema.json`, decoded and
// turned into domain values. Fixture-only: the API and persistence codecs arrive in slice 4b.

/// `$defs/goal_settings_shape`: a version's settings, possibly invalid.
struct SettingsShape: Decodable {
    struct ScheduleShape: Decodable {
        let kind: String
        let weekdays: [String]?
        let every: Int?
        let anchorDate: String?
        let days: [Int]?
        let dates: [String]?
        let calendar: String?
        let ranges: [RangeShape]?
    }

    struct RangeShape: Decodable {
        let start: MonthDayShape
        let end: MonthDayShape
    }

    struct MonthDayShape: Decodable {
        let month: Int
        let day: Int
    }

    struct ActivePeriodShape: Decodable {
        let startDate: String
        let endDate: String?
        let durationDays: Int?
    }

    struct CountPolicyShape: Decodable {
        let minimum: Int64?
        let target: Int64?
        let maximum: Int64?
        let streakThreshold: StreakThresholdShape
    }

    /// A name (`any_count`, `daily_pace`, …) or `{"amount": N}`.
    struct StreakThresholdShape: Decodable {
        let threshold: StreakThreshold

        init(from decoder: any Decoder) throws {
            let value = try decoder.singleValueContainer()
            if let amount = try? value.decode(StreakAmountShape.self) {
                threshold = .amount(amount.amount)
                return
            }
            let name = try value.decode(String.self)
            switch name {
            case "any_count": threshold = .anyCount
            case "minimum": threshold = .minimum
            case "target": threshold = .target
            case "maximum": threshold = .maximum
            case "daily_pace": threshold = .dailyPace
            default: throw FixtureValue.Invalid(value: "streak_threshold \(name)")
            }
        }
    }

    struct SessionShape: Decodable {
        let id: String
        let kind: String
        let prayer: String?
        let time: String?
        let from: String?
        let to: String?
        let target: Int64?
    }

    struct RequirementShape: Decodable {
        let type: String
        let period: String?
        let days: Int?
    }

    struct MakeUpShape: Decodable {
        let window: String
        let fill: String
    }

    let schedule: ScheduleShape
    let activePeriod: ActivePeriodShape
    let countPolicy: CountPolicyShape
    let sessions: [SessionShape]
    let requirement: RequirementShape
    let completion: String
    let makeUp: MakeUpShape

    /// Valid settings; invalid ones fail the case.
    func settings() throws -> GoalSettings {
        try construct().get()
    }

    /// The settings through `GoalSettings`' validating initializer; `.failure` when the shape is
    /// sound but the settings are invalid. Throws only when the shape can't be read.
    func construct() throws -> Result<GoalSettings, GoalValidationError> {
        let schedule = try schedule.domain()
        let activePeriod = try activePeriod.domain()
        let countPolicy = CountPolicy(
            minimum: countPolicy.minimum, target: countPolicy.target, maximum: countPolicy.maximum,
            streakThreshold: countPolicy.streakThreshold.threshold)
        let sessions = try sessions.map { try $0.domain() }
        let requirement = try requirement.domain()
        let completion = try FixtureValue.require(
            CompletionPolicy(rawValue: FixtureValue.camelCase(completion)), "completion \(completion)")
        let makeUp = MakeUp(
            window: try FixtureValue.require(MakeUp.Window(rawValue: makeUp.window), "make_up window"),
            fill: try FixtureValue.require(MakeUp.Fill(rawValue: makeUp.fill), "make_up fill"))
        return Result { () throws(GoalValidationError) in
            try GoalSettings(
                schedule: schedule, activePeriod: activePeriod, countPolicy: countPolicy, sessions: sessions,
                requirement: requirement, completion: completion, makeUp: makeUp)
        }
    }

    /// The structural fields, which can be read even from invalid settings.
    func structure() throws -> GoalStructure {
        GoalStructure(
            schedule: try schedule.domain(), requirement: try requirement.domain(),
            start: try FixtureValue.day(activePeriod.startDate))
    }
}

/// `{"amount": N}`, a streak threshold of its own.
private struct StreakAmountShape: Decodable {
    let amount: Int64
}

/// `$defs/goal_shape`: settings plus pauses and excused days.
struct GoalShape: Decodable {
    let settings: SettingsShape
    let paused: [PausedShape]
    let excused: [String]

    private enum CodingKeys: String, CodingKey {
        case paused, excused
    }

    init(from decoder: any Decoder) throws {
        settings = try SettingsShape(from: decoder)
        let values = try decoder.container(keyedBy: CodingKeys.self)
        paused = try values.decode([PausedShape].self, forKey: .paused)
        excused = try values.decode([String].self, forKey: .excused)
    }

    /// A valid goal (the schema's `goal`, which rule fixtures use). An invalid one fails the case.
    func goal() throws -> Goal {
        Goal(settings: try settings.settings(), paused: try pausedRanges(), excused: try excusedDays())
    }

    func pausedRanges() throws -> [PausedRange] {
        try paused.map { PausedRange(from: try FixtureValue.day($0.from), to: try $0.to.map(FixtureValue.day)) }
    }

    func excusedDays() throws -> [CalendarDay] {
        try excused.map(FixtureValue.day)
    }
}

struct PausedShape: Decodable {
    let from: String
    let to: String?
}

extension SettingsShape.ScheduleShape {
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
        case "hijri_month_days":
            return .hijriMonthDays(Set(try FixtureValue.require(days, "days")))
        case "yearly":
            let name = try FixtureValue.require(calendar, "calendar")
            let yearlyCalendar = try FixtureValue.require(YearlyCalendar(rawValue: name), "calendar \(name)")
            let ranges = try FixtureValue.require(ranges, "ranges").map {
                YearlyRange(
                    start: MonthDay(month: $0.start.month, day: $0.start.day),
                    end: MonthDay(month: $0.end.month, day: $0.end.day)
                )
            }
            return .yearly(yearlyCalendar, ranges: ranges)
        default:
            throw FixtureValue.Invalid(value: "schedule kind \(kind)")
        }
    }
}

extension SettingsShape.ActivePeriodShape {
    func domain() throws -> ActivePeriod {
        ActivePeriod(
            start: try FixtureValue.day(startDate), end: try endDate.map(FixtureValue.day), durationDays: durationDays)
    }
}

extension SettingsShape.SessionShape {
    func domain() throws -> GoalSession {
        GoalSession(id: id, kind: try sessionKind(), target: target)
    }

    private func sessionKind() throws -> SessionKind {
        switch kind {
        case "anytime": return .anytime
        case "before_prayer": return .beforePrayer(try domainPrayer())
        case "after_prayer": return .afterPrayer(try domainPrayer())
        case "at_time": return .atTime(try Self.time(time, "time"))
        case "between": return .between(from: try Self.time(from, "from"), to: try Self.time(to, "to"))
        default: throw FixtureValue.Invalid(value: "session kind \(kind)")
        }
    }

    private func domainPrayer() throws -> Prayer {
        let name = try FixtureValue.require(prayer, "prayer")
        return try FixtureValue.require(Prayer(rawValue: name), "prayer \(name)")
    }

    private static func time(_ string: String?, _ name: String) throws -> TimeOfDay {
        let value = try FixtureValue.require(string, name)
        return try FixtureValue.require(TimeOfDay(value), "\(name) \(value)")
    }
}

extension SettingsShape.RequirementShape {
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
        return try FixtureValue.require(Period(rawValue: FixtureValue.camelCase(name)), "period \(name)")
    }
}

/// A Hijri month-start correction (`hijri-calendar.schema.json`'s `correction_shape`).
struct CorrectionShape: Decodable {
    let year: Int
    let month: Int
    let offsetDays: Int

    var correction: HijriCorrection {
        HijriCorrection(year: year, month: month, offsetDays: offsetDays)
    }
}

/// `$defs/count_entry`.
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

    static func id(_ string: String) throws -> AwradID {
        try require(AwradID(string), "id \(string)")
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
