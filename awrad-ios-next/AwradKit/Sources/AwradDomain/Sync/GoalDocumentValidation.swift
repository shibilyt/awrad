import Foundation

/// Which goal documents are valid (contracts/sync/v1/fixtures/goal_document_validity.json), in two
/// layers: the structure of `$defs/goal_document` first, then, only for a structurally valid
/// document, the goal rules as field errors (`ruleErrors`). Errors are `{field, code}` with `field`
/// a JSON Pointer into the document, sorted by field, then code.
///
/// Structure: a missing member is `required`, an unknown one `not_allowed`; a wrong type, an
/// unknown enum value or session kind, a non-UUID ID or an impossible month-day is `invalid`; an
/// empty string is `blank`; text over its limit is `too_long`; a list over its limit is `too_many`,
/// except an empty `versions` list, which is `required`; repeated excused days are `duplicate`; a
/// snapshot title without any text is `required` on `/dhikr_snapshot/title`.
public enum GoalDocumentValidation {
    public static let maxNameLength = 120
    public static let maxArabicLength = 5000
    public static let maxPaused = 500
    public static let maxExcused = 1000

    /// Every problem with `json` as a goal document; empty when it's valid.
    public static func errors(in json: AwradJSON) -> [SyncFieldError] {
        let structural = structureErrors(json)
        guard structural.isEmpty else { return structural.sorted() }
        return ruleErrors(json).sorted()
    }

    static func structureErrors(_ json: AwradJSON) -> [SyncFieldError] {
        object(
            json, "",
            [
                ("dhikr_id", uuid), ("dhikr_snapshot", snapshot), ("name", nullable(label(maxNameLength))),
                ("counts", oneOf(GoalCounts.allCases.map(\.rawValue))), ("created_on", date), ("versions", versions),
                ("paused", list(max: maxPaused, item: pausedRange)), ("excused", excused),
                ("ended", nullable(ended)),
            ])
    }

    // MARK: - Members

    typealias Rule = (AwradJSON, String) -> [SyncFieldError]

    private static func snapshot(_ json: AwradJSON, _ path: String) -> [SyncFieldError] {
        let title: Rule = { json, path in
            var errors = object(
                json, path, ["en", "ar", "ml"].map { ($0, nullable(label(maxNameLength))) })
            if let texts = json.objectValue, errors.isEmpty, !texts.values.contains(where: { $0.stringValue != nil }) {
                errors.append(SyncFieldError(field: path, code: "required"))
            }
            return errors
        }
        let kinds = DhikrKind.allCases.map(\.rawValue)
        return object(json, path, [("title", title), ("arabic", label(maxArabicLength)), ("kind", oneOf(kinds))])
    }

    private static func versions(_ json: AwradJSON, _ path: String) -> [SyncFieldError] {
        guard let items = json.arrayValue else { return [invalid(path)] }
        if items.isEmpty { return [SyncFieldError(field: path, code: "required")] }
        if items.count > GoalTimeline.maximumVersions { return [SyncFieldError(field: path, code: "too_many")] }
        return items.enumerated().flatMap { version($1, "\(path)/\($0)") }
    }

    private static func version(_ json: AwradJSON, _ path: String) -> [SyncFieldError] {
        let completions = CompletionPolicy.allCases.map(\.wireName)
        let makeUp: Rule = { json, path in
            object(
                json, path,
                [
                    ("window", oneOf(MakeUp.Window.allCases.map(\.rawValue))),
                    ("fill", oneOf(MakeUp.Fill.allCases.map(\.rawValue))),
                ])
        }
        return object(
            json, path,
            [
                ("from", date), ("schedule", schedule), ("active_period", activePeriod), ("count_policy", countPolicy),
                ("sessions", list(max: .max, item: session)), ("requirement", requirement),
                ("completion", oneOf(completions)), ("make_up", makeUp),
            ])
    }

    private static func activePeriod(_ json: AwradJSON, _ path: String) -> [SyncFieldError] {
        object(
            json, path,
            [("start_date", date), ("end_date", nullable(date)), ("duration_days", nullable(integer(1...36600)))])
    }

    private static func countPolicy(_ json: AwradJSON, _ path: String) -> [SyncFieldError] {
        let threshold: Rule = { json, path in
            if json.objectValue != nil { return object(json, path, [("amount", integer(1...maxCount))]) }
            return oneOf(["any_count", "minimum", "target", "maximum", "daily_pace"])(json, path)
        }
        return object(
            json, path,
            [
                ("minimum", nullable(count)), ("target", nullable(count)), ("maximum", nullable(count)),
                ("streak_threshold", threshold),
            ])
    }

    private static func requirement(_ json: AwradJSON, _ path: String) -> [SyncFieldError] {
        let periods = Period.allCases.map(\.wireName)
        return variant(
            json, path, discriminator: "type",
            [
                "per_due_date": [], "cumulative_total": [], "tracker": [],
                "period_total": [("period", oneOf(periods))],
                "days_per_period": [("period", oneOf(periods)), ("days", integer(1...31))],
            ])
    }

    private static func session(_ json: AwradJSON, _ path: String) -> [SyncFieldError] {
        let prayers = Prayer.allCases.map(\.rawValue)
        let common: [(String, Rule)] = [("id", sessionID), ("target", nullable(count))]
        return variant(
            json, path, discriminator: "kind",
            [
                "anytime": common, "before_prayer": common + [("prayer", oneOf(prayers))],
                "after_prayer": common + [("prayer", oneOf(prayers))], "at_time": common + [("time", time)],
                "between": common + [("from", time), ("to", time)],
            ])
    }

    private static func schedule(_ json: AwradJSON, _ path: String) -> [SyncFieldError] {
        let weekdays = Weekday.allCases.map(\.rawValue)
        let yearly: Rule = { json, path in
            let calendar = json["calendar"]?.stringValue.flatMap(YearlyCalendar.init(rawValue:))
            let ranges: Rule = { json, path in
                guard let calendar else { return [] }
                let errors = list(max: .max, item: yearlyRange(calendar))(json, path)
                return errors.isEmpty && json.arrayValue?.isEmpty == true ? [invalid(path)] : errors
            }
            return object(
                json, path,
                [
                    ("kind", { _, _ in [] }), ("calendar", oneOf(YearlyCalendar.allCases.map(\.rawValue))),
                    ("ranges", ranges),
                ])
        }
        if json["kind"]?.stringValue == "yearly", json.objectValue != nil { return yearly(json, path) }
        return variant(
            json, path, discriminator: "kind",
            [
                "every_day": [], "one_time": [], "weekdays": [("weekdays", set(min: 1, item: oneOf(weekdays)))],
                "every_n_days": [("every", integer(1...366)), ("anchor_date", nullable(date))],
                "month_days": [("days", set(min: 1, item: integer(1...31)))],
                "hijri_month_days": [("days", set(min: 1, item: integer(1...30)))],
                "specific_dates": [("dates", set(min: 1, item: date))],
                "yearly": [],
            ])
    }

    private static func yearlyRange(_ calendar: YearlyCalendar) -> Rule {
        let monthDay: Rule = { json, path in
            guard let members = json.objectValue, Set(members.keys) == ["month", "day"],
                let month = members["month"]?.intValue, let day = members["day"]?.intValue,
                (1...12).contains(month), day >= 1,
                day <= (calendar == .hijri ? 30 : CalendarDay.daysInMonth(year: 2000, month: month))
            else { return [invalid(path)] }
            return []
        }
        return { json, path in object(json, path, [("start", monthDay), ("end", monthDay)]) }
    }

    private static func pausedRange(_ json: AwradJSON, _ path: String) -> [SyncFieldError] {
        object(json, path, [("from", date), ("to", nullable(date))])
    }

    private static func excused(_ json: AwradJSON, _ path: String) -> [SyncFieldError] {
        guard let items = json.arrayValue else { return [invalid(path)] }
        if items.count > maxExcused { return [SyncFieldError(field: path, code: "too_many")] }
        let errors = items.enumerated().flatMap { date($1, "\(path)/\($0)") }
        guard errors.isEmpty else { return errors }
        return Set(items).count == items.count ? [] : [SyncFieldError(field: path, code: "duplicate")]
    }

    private static func ended(_ json: AwradJSON, _ path: String) -> [SyncFieldError] {
        object(json, path, [("on", date), ("reason", oneOf(GoalEnding.Reason.allCases.map(\.rawValue)))])
    }
}

// MARK: - Building blocks

extension GoalDocumentValidation {
    static let maxCount = 9_007_199_254_740_991

    static func invalid(_ path: String) -> SyncFieldError {
        SyncFieldError(field: path, code: "invalid")
    }

    /// An object with exactly `members`: unknown ones are `not_allowed`, missing ones `required`.
    static func object(_ json: AwradJSON, _ path: String, _ members: [(String, Rule)]) -> [SyncFieldError] {
        guard let values = json.objectValue else { return [invalid(path)] }
        let names = Set(members.map(\.0))
        var errors = values.keys.filter { !names.contains($0) }.map {
            SyncFieldError(field: "\(path)/\($0)", code: "not_allowed")
        }
        for (name, rule) in members {
            guard let value = values[name] else {
                errors.append(SyncFieldError(field: "\(path)/\(name)", code: "required"))
                continue
            }
            errors += rule(value, "\(path)/\(name)")
        }
        return errors
    }

    /// An object whose `discriminator` picks its other members.
    static func variant(
        _ json: AwradJSON, _ path: String, discriminator: String, _ variants: [String: [(String, Rule)]]
    ) -> [SyncFieldError] {
        guard let values = json.objectValue else { return [invalid(path)] }
        guard let tag = values[discriminator] else {
            return [SyncFieldError(field: "\(path)/\(discriminator)", code: "required")]
        }
        guard let members = tag.stringValue.flatMap({ variants[$0] }) else {
            return [invalid("\(path)/\(discriminator)")]
        }
        return object(json, path, [(discriminator, { _, _ in [] })] + members)
    }

    static func nullable(_ rule: @escaping Rule) -> Rule {
        { json, path in json == .null ? [] : rule(json, path) }
    }

    static func oneOf(_ values: [String]) -> Rule {
        { json, path in json.stringValue.map(values.contains) == true ? [] : [invalid(path)] }
    }

    static func integer(_ range: ClosedRange<Int>) -> Rule {
        { json, path in json.intValue.map(range.contains) == true ? [] : [invalid(path)] }
    }

    static var count: Rule { integer(0...maxCount) }

    static func label(_ maxLength: Int) -> Rule {
        { json, path in
            guard let text = json.stringValue else { return [invalid(path)] }
            if text.isEmpty || CustomDhikrValidation.isBlank(text) {
                return [SyncFieldError(field: path, code: "blank")]
            }
            return text.unicodeScalars.count > maxLength ? [SyncFieldError(field: path, code: "too_long")] : []
        }
    }

    static func date(_ json: AwradJSON, _ path: String) -> [SyncFieldError] {
        json.stringValue.flatMap(CalendarDay.init) == nil ? [invalid(path)] : []
    }

    static func time(_ json: AwradJSON, _ path: String) -> [SyncFieldError] {
        json.stringValue.flatMap(TimeOfDay.init) == nil ? [invalid(path)] : []
    }

    static func uuid(_ json: AwradJSON, _ path: String) -> [SyncFieldError] {
        json.stringValue.flatMap(AwradID.init) == nil ? [invalid(path)] : []
    }

    /// `^[a-z][a-z0-9_]*$`.
    static func sessionID(_ json: AwradJSON, _ path: String) -> [SyncFieldError] {
        guard let id = json.stringValue, let first = id.unicodeScalars.first, ("a"..."z").contains(first),
            id.unicodeScalars.allSatisfy({ ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "_" })
        else { return [invalid(path)] }
        return []
    }

    /// A list of at most `max` items, each checked.
    static func list(max: Int, item: @escaping Rule) -> Rule {
        { json, path in
            guard let items = json.arrayValue else { return [invalid(path)] }
            if items.count > max { return [SyncFieldError(field: path, code: "too_many")] }
            return items.enumerated().flatMap { item($1, "\(path)/\($0)") }
        }
    }

    /// A list of at least `min` items without repeats, each checked; a short or repeating list is
    /// `invalid`.
    static func set(min: Int, item: @escaping Rule) -> Rule {
        { json, path in
            guard let items = json.arrayValue else { return [invalid(path)] }
            let errors = items.enumerated().flatMap { item($1, "\(path)/\($0)") }
            guard errors.isEmpty else { return errors }
            return items.count >= min && Set(items).count == items.count ? [] : [invalid(path)]
        }
    }
}
