import Foundation

// Rule: validity (contracts/goal-model/v1/fixtures/goal_validity.json).

/// Why goal settings or a timeline can't be built. The initializers throw it, so an invalid goal
/// never exists; platforms reject one at construction, sync and import.
public struct GoalValidationError: Error, Hashable, Sendable {
    /// One reason a goal is invalid. The raw value is the contract's error code.
    public enum Code: String, CaseIterable, Hashable, Sendable {
        /// No target on a goal that isn't a tracker.
        case targetRequired = "target_required"
        /// A session without a target, when the goal isn't a tracker.
        case sessionTargetRequired = "session_target_required"
        /// The streak threshold names a minimum, target or maximum that isn't set.
        case streakThresholdValueRequired = "streak_threshold_value_required"
        /// `dailyPace` on anything but a total with an end.
        case streakPaceNotAllowed = "streak_pace_not_allowed"
        /// Both an end date and a number of days.
        case endDateAndDuration = "end_date_and_duration"
        /// A make-up window on a goal that isn't per due date, or a total counting at an amount
        /// filled to the streak.
        case makeUpNotAllowed = "make_up_not_allowed"
        /// Sessions together with a minimum or cap on the goal.
        case sessionsWithMinimumOrCap = "sessions_with_minimum_or_cap"
        /// A session ID that isn't derived from its kind.
        case sessionIDMismatch = "session_id_mismatch"
        /// Two sessions with one ID.
        case sessionDuplicate = "session_duplicate"
        /// A `between` window from a time to the same time.
        case sessionWindowEmpty = "session_window_empty"
        /// Versions disagree on a structural field (`GoalStructure`).
        case structuralChange = "structural_change"
        /// Version `from` days not strictly increasing.
        case versionsOutOfOrder = "versions_out_of_order"
        /// The first version doesn't start on `createdOn` (or there's no version).
        case firstVersionNotCreatedOn = "first_version_not_created_on"
    }

    /// Every reason, without duplicates, sorted alphabetically by code. Never empty.
    public let codes: [Code]

    public init(_ codes: Set<Code>) {
        self.codes = codes.sorted { $0.rawValue < $1.rawValue }
    }
}

extension GoalSettings {
    /// Every reason these settings would be invalid (README.md, Validity).
    ///
    /// Without sessions, the goal's own count policy needs a target (unless it's a tracker) and the
    /// value its streak threshold names. With sessions, each session needs a target (unless it's a
    /// tracker) and the ID its kind derives, IDs are unique, and the goal has no minimum or cap.
    public static func validationCodes(
        activePeriod: ActivePeriod,
        countPolicy: CountPolicy,
        sessions: [GoalSession],
        requirement: Requirement,
        makeUp: MakeUp
    ) -> Set<GoalValidationError.Code> {
        var codes =
            sessions.isEmpty
            ? countPolicyCodes(countPolicy, requirement: requirement)
            : sessionCodes(sessions, countPolicy: countPolicy, requirement: requirement)
        if activePeriod.end != nil, activePeriod.durationDays != nil {
            codes.insert(.endDateAndDuration)
        }
        if makeUp.window != .off, !makeUpAllowed(makeUp, countPolicy: countPolicy, requirement: requirement) {
            codes.insert(.makeUpNotAllowed)
        }
        if countPolicy.streakThreshold == .dailyPace, requirement != .cumulativeTotal || !activePeriod.hasEnd {
            codes.insert(.streakPaceNotAllowed)
        }
        return codes
    }

    private static func countPolicyCodes(
        _ policy: CountPolicy, requirement: Requirement
    ) -> Set<GoalValidationError.Code> {
        var codes: Set<GoalValidationError.Code> = []
        if !policy.hasStreakThresholdValue { codes.insert(.streakThresholdValueRequired) }
        if requirement != .tracker, policy.target == nil { codes.insert(.targetRequired) }
        return codes
    }

    private static func sessionCodes(
        _ sessions: [GoalSession], countPolicy: CountPolicy, requirement: Requirement
    ) -> Set<GoalValidationError.Code> {
        var codes: Set<GoalValidationError.Code> = []
        for session in sessions {
            if requirement != .tracker, session.target == nil { codes.insert(.sessionTargetRequired) }
            if session.id != session.kind.sessionID { codes.insert(.sessionIDMismatch) }
            if case .between(let from, let to) = session.kind, from == to { codes.insert(.sessionWindowEmpty) }
        }
        if countPolicy.minimum != nil || countPolicy.maximum != nil { codes.insert(.sessionsWithMinimumOrCap) }
        if Set(sessions.map(\.id)).count != sessions.count { codes.insert(.sessionDuplicate) }
        return codes
    }

    /// Make-up is for per-due-date goals, and for totals whose streak counts at an amount, always
    /// filled to that amount (decision 48).
    private static func makeUpAllowed(_ makeUp: MakeUp, countPolicy: CountPolicy, requirement: Requirement) -> Bool {
        switch requirement {
        case .perDueDate:
            return true
        case .cumulativeTotal:
            guard case .amount = countPolicy.streakThreshold else { return false }
            return makeUp.fill == .streak
        case .periodTotal, .daysPerPeriod, .tracker:
            return false
        }
    }
}

extension GoalTimeline {
    /// The reasons a timeline's versions are invalid as a whole: out of order, not starting on
    /// `createdOn`, or with a structural change. Each version's own settings are checked by
    /// `GoalSettings`; a document has both sets of errors.
    public static func validationCodes(
        createdOn: CalendarDay, versions: [(from: CalendarDay, structure: GoalStructure)]
    ) -> Set<GoalValidationError.Code> {
        var codes: Set<GoalValidationError.Code> = []
        guard let first = versions.first else { return [.firstVersionNotCreatedOn] }
        if zip(versions, versions.dropFirst()).contains(where: { $0.from >= $1.from }) {
            codes.insert(.versionsOutOfOrder)
        }
        if first.from != createdOn { codes.insert(.firstVersionNotCreatedOn) }
        if versions.contains(where: { $0.structure != first.structure }) { codes.insert(.structuralChange) }
        return codes
    }
}

extension CountPolicy {
    /// Whether the value the streak threshold names is set (the other thresholds need none).
    var hasStreakThresholdValue: Bool {
        switch streakThreshold {
        case .anyCount, .dailyPace, .amount: true
        case .minimum: minimum != nil
        case .target: target != nil
        case .maximum: maximum != nil
        }
    }
}
