import Foundation

// Rule: validity (contracts/goal-model/v1/fixtures/goal_validity.json).

/// Why a goal can't be built. `Goal.init` throws it, so an invalid goal never exists.
public struct GoalValidationError: Error, Hashable, Sendable {
    /// One reason a goal is invalid. The raw value is the contract's error code.
    public enum Code: String, CaseIterable, Hashable, Sendable {
        /// A goal with sessions that isn't a tracker has a session without a target.
        case sessionTargetRequired = "session_target_required"
        /// A count policy's streak threshold is its minimum, target or maximum, which isn't set.
        case streakThresholdValueRequired = "streak_threshold_value_required"
        /// A goal without sessions that isn't a tracker has no target.
        case targetRequired = "target_required"
    }

    /// Every reason, without duplicates, sorted alphabetically by code. Never empty.
    public let codes: [Code]

    init(_ codes: Set<Code>) {
        self.codes = codes.sorted { $0.rawValue < $1.rawValue }
    }
}

extension Goal {
    /// Checks the parts that make a goal valid, collecting every reason it isn't.
    ///
    /// The count policy that applies is checked: the goal's own without sessions, and each
    /// session's with sessions (the goal's own numbers aren't used then).
    /// - Every requirement except tracker needs a target on every policy that applies.
    /// - Every policy that applies needs the value its streak threshold points at.
    static func validate(
        countPolicy: CountPolicy,
        sessions: [GoalSession],
        requirement: Requirement
    ) throws(GoalValidationError) {
        let policies = sessions.isEmpty ? [countPolicy] : sessions.map(\.countPolicy)
        var codes: Set<GoalValidationError.Code> = []
        if requirement != .tracker, policies.contains(where: { $0.target == nil }) {
            codes.insert(sessions.isEmpty ? .targetRequired : .sessionTargetRequired)
        }
        if !policies.allSatisfy(\.hasStreakThresholdValue) {
            codes.insert(.streakThresholdValueRequired)
        }
        guard codes.isEmpty else { throw GoalValidationError(codes) }
    }
}

extension CountPolicy {
    /// Whether the value the streak threshold points at is set (any count needs none).
    var hasStreakThresholdValue: Bool {
        switch streakThreshold {
        case .anyCount: true
        case .minimum: minimum != nil
        case .target: target != nil
        case .maximum: maximum != nil
        }
    }
}
