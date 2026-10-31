import Foundation

// The `goal` and `goal_order` sync documents' wire JSON (contracts/goal-model/v1/goal-model.schema.json,
// `$defs/goal_document` and `$defs/goal_order_document`).
//
// Sets in a schedule (weekdays, month days, dates) are written in a canonical order: weekdays
// Monday first, numbers and dates ascending. A document made elsewhere in another order reads the
// same, and is equal as a value.

extension GoalDocument {
    /// The document from its wire JSON, if it has the schema's shape and follows the goal rules.
    /// Errors name the first member that's wrong (`invalid`), or the version whose settings break a
    /// goal rule; the server reports goal rules in full (sync/v1 README, "Goal rules as field errors").
    public init(json: AwradJSON) throws(SyncDocumentError) {
        do {
            self = try Self.read(JSONReader(json, path: ""))
        } catch let error as JSONReader.Failure {
            throw SyncDocumentError(type: .goal, errors: [SyncFieldError(field: error.field, code: "invalid")])
        } catch {
            throw SyncDocumentError(type: .goal, errors: [SyncFieldError(field: "", code: "invalid")])
        }
    }

    /// The wire form, every member present.
    public var json: AwradJSON {
        let title = dhikrSnapshot.title
        return .object([
            "dhikr_id": .string(dhikrID.description),
            "dhikr_snapshot": .object([
                "title": .object(["en": .optional(title.en), "ar": .optional(title.ar), "ml": .optional(title.ml)]),
                "arabic": .string(dhikrSnapshot.arabic),
                "kind": .string(dhikrSnapshot.kind.rawValue),
            ]),
            "name": .optional(name),
            "counts": .string(counts.rawValue),
            "created_on": .string(timeline.createdOn.description),
            "versions": .array(timeline.versions.map(\.json)),
            "paused": .array(timeline.paused.map { .object(["from": .day($0.from), "to": .day($0.to)]) }),
            "excused": .array(timeline.excused.map { .string($0.description) }),
            "ended": timeline.ended.map {
                .object(["on": .string($0.on.description), "reason": .string($0.reason.rawValue)])
            } ?? .null,
        ])
    }

    private static func read(_ json: JSONReader) throws -> GoalDocument {
        let snapshot = try json["dhikr_snapshot"]
        let title = try snapshot["title"]
        let versions = try json["versions"].array().map(GoalVersion.read)
        let timeline: GoalTimeline
        do {
            timeline = try GoalTimeline(
                createdOn: try json["created_on"].day(), versions: versions,
                paused: try json["paused"].array().map {
                    PausedRange(from: try $0["from"].day(), to: try $0["to"].optionalDay())
                },
                excused: try json["excused"].array().map { try $0.day() },
                ended: try json["ended"].optional().map {
                    GoalEnding(on: try $0["on"].day(), reason: try $0["reason"].raw(GoalEnding.Reason.self))
                })
        } catch is GoalValidationError {
            throw JSONReader.Failure(field: "/versions")
        }
        return GoalDocument(
            dhikrID: try json["dhikr_id"].id(),
            dhikrSnapshot: DhikrSnapshot(
                title: LanguageTexts(
                    en: try title["en"].optionalString(), ar: try title["ar"].optionalString(),
                    ml: try title["ml"].optionalString()),
                arabic: try snapshot["arabic"].string(), kind: try snapshot["kind"].raw(DhikrKind.self)),
            name: try json["name"].optionalString(),
            counts: try json["counts"].raw(GoalCounts.self),
            timeline: timeline)
    }
}

extension GoalOrder {
    /// The document from its wire JSON: exactly `{goal_ids}`, wire UUIDs without repeats.
    public init(json: AwradJSON) throws(SyncDocumentError) {
        let invalid = SyncDocumentError(type: .goalOrder, errors: [SyncFieldError(field: "/goal_ids", code: "invalid")])
        guard let members = json.objectValue, Set(members.keys) == ["goal_ids"],
            let items = members["goal_ids"]?.arrayValue
        else { throw SyncDocumentError(type: .goalOrder, errors: [SyncFieldError(field: "", code: "invalid")]) }
        let ids = items.compactMap { $0.stringValue.flatMap(AwradID.init) }
        guard ids.count == items.count, Set(ids).count == ids.count else { throw invalid }
        self.init(goalIDs: ids)
    }

    public var json: AwradJSON {
        .object(["goal_ids": .array(goalIDs.map { .string($0.description) })])
    }
}

extension GoalVersion {
    var json: AwradJSON {
        guard case .object(var members) = settings.json else { return settings.json }
        members["from"] = .string(from.description)
        return .object(members)
    }

    fileprivate static func read(_ json: JSONReader) throws -> GoalVersion {
        GoalVersion(from: try json["from"].day(), settings: try GoalSettings.read(json))
    }
}

extension GoalSettings {
    /// The settings' wire members (`$defs/goal_settings`).
    var json: AwradJSON {
        .object([
            "schedule": schedule.json,
            "active_period": .object([
                "start_date": .string(activePeriod.start.description), "end_date": .day(activePeriod.end),
                "duration_days": activePeriod.durationDays.map(AwradJSON.int) ?? .null,
            ]),
            "count_policy": countPolicy.json,
            "sessions": .array(sessions.map(\.json)),
            "requirement": requirement.json,
            "completion": .string(completion.wireName),
            "make_up": .object(["window": .string(makeUp.window.rawValue), "fill": .string(makeUp.fill.rawValue)]),
        ])
    }

    fileprivate static func read(_ json: JSONReader) throws -> GoalSettings {
        let period = try json["active_period"]
        let makeUp = try json["make_up"]
        let completion = try json["completion"].string()
        guard let policy = CompletionPolicy.allCases.first(where: { $0.wireName == completion }) else {
            throw JSONReader.Failure(field: json.path + "/completion")
        }
        do {
            return try GoalSettings(
                schedule: try Schedule.read(json["schedule"]),
                activePeriod: ActivePeriod(
                    start: try period["start_date"].day(), end: try period["end_date"].optionalDay(),
                    durationDays: try period["duration_days"].optional().map { try $0.int() }),
                countPolicy: try CountPolicy.read(json["count_policy"]),
                sessions: try json["sessions"].array().map(GoalSession.read),
                requirement: try Requirement.read(json["requirement"]),
                completion: policy,
                makeUp: MakeUp(
                    window: try makeUp["window"].raw(MakeUp.Window.self), fill: try makeUp["fill"].raw(MakeUp.Fill.self)
                ))
        } catch is GoalValidationError {
            throw JSONReader.Failure(field: json.path)
        }
    }
}

extension CompletionPolicy {
    var wireName: String {
        switch self {
        case .never: "never"
        case .whenTargetReached: "when_target_reached"
        case .whenDurationEnded: "when_duration_ended"
        }
    }
}

extension Schedule {
    var json: AwradJSON {
        switch self {
        case .everyDay: .object(["kind": .string("every_day")])
        case .oneTime: .object(["kind": .string("one_time")])
        case .weekdays(let days):
            .object([
                "kind": .string("weekdays"),
                "weekdays": .array(Weekday.allCases.filter(days.contains).map { .string($0.rawValue) }),
            ])
        case .everyNDays(let every, let anchor):
            .object(["kind": .string("every_n_days"), "every": .int(every), "anchor_date": .day(anchor)])
        case .monthDays(let days):
            .object(["kind": .string("month_days"), "days": .array(days.sorted().map(AwradJSON.int))])
        case .specificDates(let dates):
            .object([
                "kind": .string("specific_dates"), "dates": .array(dates.sorted().map { .string($0.description) }),
            ])
        case .hijriMonthDays(let days):
            .object(["kind": .string("hijri_month_days"), "days": .array(days.sorted().map(AwradJSON.int))])
        case .yearly(let calendar, let ranges):
            .object([
                "kind": .string("yearly"), "calendar": .string(calendar.rawValue),
                "ranges": .array(ranges.map { .object(["start": $0.start.json, "end": $0.end.json]) }),
            ])
        }
    }

    fileprivate static func read(_ json: JSONReader) throws -> Schedule {
        switch try json["kind"].string() {
        case "every_day": return .everyDay
        case "one_time": return .oneTime
        case "weekdays": return .weekdays(Set(try json["weekdays"].array().map { try $0.raw(Weekday.self) }))
        case "every_n_days": return .everyNDays(try json["every"].int(), anchor: try json["anchor_date"].optionalDay())
        case "month_days": return .monthDays(Set(try json["days"].array().map { try $0.int() }))
        case "specific_dates": return .specificDates(Set(try json["dates"].array().map { try $0.day() }))
        case "hijri_month_days": return .hijriMonthDays(Set(try json["days"].array().map { try $0.int() }))
        case "yearly":
            return .yearly(
                try json["calendar"].raw(YearlyCalendar.self),
                ranges: try json["ranges"].array().map {
                    YearlyRange(start: try MonthDay.read($0["start"]), end: try MonthDay.read($0["end"]))
                })
        default: throw JSONReader.Failure(field: json.path + "/kind")
        }
    }
}

extension MonthDay {
    var json: AwradJSON { .object(["month": .int(month), "day": .int(day)]) }

    fileprivate static func read(_ json: JSONReader) throws -> MonthDay {
        MonthDay(month: try json["month"].int(), day: try json["day"].int())
    }
}

extension CountPolicy {
    var json: AwradJSON {
        .object([
            "minimum": minimum.map { .int(Int($0)) } ?? .null, "target": target.map { .int(Int($0)) } ?? .null,
            "maximum": maximum.map { .int(Int($0)) } ?? .null, "streak_threshold": streakThreshold.json,
        ])
    }

    fileprivate static func read(_ json: JSONReader) throws -> CountPolicy {
        CountPolicy(
            minimum: try json["minimum"].optionalCount(), target: try json["target"].optionalCount(),
            maximum: try json["maximum"].optionalCount(),
            streakThreshold: try StreakThreshold.read(json["streak_threshold"]))
    }
}

extension StreakThreshold {
    private static let names: [String: StreakThreshold] = [
        "any_count": .anyCount, "minimum": .minimum, "target": .target, "maximum": .maximum, "daily_pace": .dailyPace,
    ]

    var json: AwradJSON {
        if case .amount(let amount) = self { return .object(["amount": .int(Int(amount))]) }
        return .string(Self.names.first { $0.value == self }?.key ?? "")
    }

    fileprivate static func read(_ json: JSONReader) throws -> StreakThreshold {
        if json.json.objectValue != nil { return .amount(Int64(try json["amount"].int())) }
        guard let threshold = names[try json.string()] else { throw JSONReader.Failure(field: json.path) }
        return threshold
    }
}

extension GoalSession {
    var json: AwradJSON {
        var members: [String: AwradJSON] = ["id": .string(id), "target": target.map { .int(Int($0)) } ?? .null]
        switch kind {
        case .anytime:
            members["kind"] = .string("anytime")
        case .beforePrayer(let prayer), .afterPrayer(let prayer):
            members["kind"] = .string(kind == .beforePrayer(prayer) ? "before_prayer" : "after_prayer")
            members["prayer"] = .string(prayer.rawValue)
        case .atTime(let time):
            members["kind"] = .string("at_time")
            members["time"] = .string(time.description)
        case .between(let from, let to):
            members["kind"] = .string("between")
            members["from"] = .string(from.description)
            members["to"] = .string(to.description)
        }
        return .object(members)
    }

    fileprivate static func read(_ json: JSONReader) throws -> GoalSession {
        let kind: SessionKind
        switch try json["kind"].string() {
        case "anytime": kind = .anytime
        case "before_prayer": kind = .beforePrayer(try json["prayer"].raw(Prayer.self))
        case "after_prayer": kind = .afterPrayer(try json["prayer"].raw(Prayer.self))
        case "at_time": kind = .atTime(try json["time"].time())
        case "between": kind = .between(from: try json["from"].time(), to: try json["to"].time())
        default: throw JSONReader.Failure(field: json.path + "/kind")
        }
        return GoalSession(id: try json["id"].string(), kind: kind, target: try json["target"].optionalCount())
    }
}

extension Requirement {
    var json: AwradJSON {
        switch self {
        case .perDueDate: .object(["type": .string("per_due_date")])
        case .cumulativeTotal: .object(["type": .string("cumulative_total")])
        case .tracker: .object(["type": .string("tracker")])
        case .periodTotal(let period): .object(["type": .string("period_total"), "period": .string(period.wireName)])
        case .daysPerPeriod(let period, let days):
            .object(["type": .string("days_per_period"), "period": .string(period.wireName), "days": .int(days)])
        }
    }

    fileprivate static func read(_ json: JSONReader) throws -> Requirement {
        switch try json["type"].string() {
        case "per_due_date": return .perDueDate
        case "cumulative_total": return .cumulativeTotal
        case "tracker": return .tracker
        case "period_total": return .periodTotal(try Period.read(json["period"]))
        case "days_per_period": return .daysPerPeriod(try Period.read(json["period"]), days: try json["days"].int())
        default: throw JSONReader.Failure(field: json.path + "/type")
        }
    }
}

extension Period {
    var wireName: String { self == .hijriMonth ? "hijri_month" : rawValue }

    fileprivate static func read(_ json: JSONReader) throws -> Period {
        let name = try json.string()
        guard let period = allCases.first(where: { $0.wireName == name }) else {
            throw JSONReader.Failure(field: json.path)
        }
        return period
    }
}

extension AwradJSON {
    /// A day, or `null`.
    fileprivate static func day(_ day: CalendarDay?) -> AwradJSON {
        day.map { .string($0.description) } ?? .null
    }
}

/// Reads a JSON value, naming the member that's missing or of the wrong type.
private struct JSONReader {
    struct Failure: Error {
        let field: String
    }

    let json: AwradJSON
    let path: String

    init(_ json: AwradJSON, path: String) {
        self.json = json
        self.path = path
    }

    subscript(key: String) -> JSONReader {
        get throws {
            guard let value = json[key] else { throw Failure(field: "\(path)/\(key)") }
            return JSONReader(value, path: "\(path)/\(key)")
        }
    }

    func optional() -> JSONReader? { json == .null ? nil : self }

    func string() throws -> String {
        guard let value = json.stringValue else { throw Failure(field: path) }
        return value
    }

    func int() throws -> Int {
        guard let value = json.intValue else { throw Failure(field: path) }
        return value
    }

    func array() throws -> [JSONReader] {
        guard let items = json.arrayValue else { throw Failure(field: path) }
        return items.enumerated().map { JSONReader($1, path: "\(path)/\($0)") }
    }

    func optionalString() throws -> String? { try optional()?.string() }
    func optionalCount() throws -> Int64? { try optional().map { Int64(try $0.int()) } }
    func optionalDay() throws -> CalendarDay? { try optional()?.day() }

    func day() throws -> CalendarDay {
        guard let day = CalendarDay(try string()) else { throw Failure(field: path) }
        return day
    }

    func time() throws -> TimeOfDay {
        guard let time = TimeOfDay(try string()) else { throw Failure(field: path) }
        return time
    }

    func id() throws -> AwradID {
        guard let id = AwradID(try string()) else { throw Failure(field: path) }
        return id
    }

    func raw<Value: RawRepresentable>(_: Value.Type) throws -> Value where Value.RawValue == String {
        guard let value = Value(rawValue: try string()) else { throw Failure(field: path) }
        return value
    }
}
