import Foundation

// The second layer of goal document validity: the goal rules (goal_validity) as field errors,
// for a structurally valid document (contracts/sync/v1/README.md, "Goal documents").

extension GoalDocumentValidation {
    /// The goal rules' errors of a structurally valid document, each on the version (`N`) and
    /// session (`M`) it's in.
    static func ruleErrors(_ json: AwradJSON) -> [SyncFieldError] {
        let document = JSONReader(json, path: "")
        guard let items = try? document["versions"].array(), let createdOn = try? document["created_on"].day() else {
            return [invalid("")]
        }
        var errors: [SyncFieldError] = []
        var versions: [(from: CalendarDay, structure: GoalStructure)] = []
        for (index, item) in items.enumerated() {
            guard let parts = try? VersionParts(item) else { return [invalid(item.path)] }
            errors += parts.errors(at: item.path)
            versions.append(
                (
                    parts.from,
                    GoalStructure(
                        schedule: parts.schedule, requirement: parts.requirement, start: parts.activePeriod.start)
                ))
            guard index > 0 else { continue }
            if versions[index].structure != versions[0].structure {
                errors.append(SyncFieldError(field: item.path, code: "mismatch"))
            }
            if versions[index].from <= versions[index - 1].from {
                errors.append(SyncFieldError(field: "\(item.path)/from", code: "range"))
            }
        }
        if versions.first?.from != createdOn {
            errors.append(SyncFieldError(field: "/versions/0/from", code: "mismatch"))
        }
        return Array(Set(errors))
    }
}

/// One version's settings, read without the goal rules so each broken rule can be named.
private struct VersionParts {
    let from: CalendarDay
    let schedule: Schedule
    let activePeriod: ActivePeriod
    let countPolicy: CountPolicy
    let sessions: [GoalSession]
    let requirement: Requirement
    let makeUp: MakeUp

    init(_ json: JSONReader) throws {
        let period = try json["active_period"]
        let makeUp = try json["make_up"]
        from = try json["from"].day()
        schedule = try Schedule.read(json["schedule"])
        activePeriod = ActivePeriod(
            start: try period["start_date"].day(), end: try period["end_date"].optionalDay(),
            durationDays: try period["duration_days"].optional().map { try $0.int() })
        countPolicy = try CountPolicy.read(json["count_policy"])
        sessions = try json["sessions"].array().map(GoalSession.read)
        requirement = try Requirement.read(json["requirement"])
        self.makeUp = MakeUp(
            window: try makeUp["window"].raw(MakeUp.Window.self), fill: try makeUp["fill"].raw(MakeUp.Fill.self))
    }

    /// The README's table "Goal rules as field errors", for this version at `path`.
    func errors(at path: String) -> [SyncFieldError] {
        let codes = GoalSettings.validationCodes(
            activePeriod: activePeriod, countPolicy: countPolicy, sessions: sessions, requirement: requirement,
            makeUp: makeUp)
        var errors: [SyncFieldError] = []
        func add(_ field: String, _ code: String) { errors.append(SyncFieldError(field: path + field, code: code)) }
        if codes.contains(.targetRequired) { add("/count_policy/target", "required") }
        if codes.contains(.streakThresholdValueRequired) || codes.contains(.streakPaceNotAllowed) {
            add("/count_policy/streak_threshold", "invalid")
        }
        if codes.contains(.endDateAndDuration) { add("/active_period/duration_days", "not_allowed") }
        if codes.contains(.makeUpNotAllowed) { add("/make_up/window", "not_allowed") }
        if codes.contains(.sessionsWithMinimumOrCap) {
            if countPolicy.minimum != nil { add("/count_policy/minimum", "not_allowed") }
            if countPolicy.maximum != nil { add("/count_policy/maximum", "not_allowed") }
        }
        var seen: Set<String> = []
        for (index, session) in sessions.enumerated() {
            let at = "/sessions/\(index)"
            if requirement != .tracker, session.target == nil { add("\(at)/target", "required") }
            if session.id != session.kind.sessionID { add("\(at)/id", "mismatch") }
            if !seen.insert(session.id).inserted { add("\(at)/id", "duplicate") }
            if case .between(let from, let to) = session.kind, from == to { add("\(at)/to", "range") }
        }
        return errors
    }
}
