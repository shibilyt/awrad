package app.awrad.core.domain.goal

/** Why a goal can't be built. The codes are `contracts/goal-model/v1/fixtures/goal_validity.json`'s. */
public enum class GoalDefinitionError {
    /** A goal with sessions, other than a tracker, has a session without a target. */
    SESSION_TARGET_REQUIRED,

    /** A streak threshold of minimum, target or maximum points at a value that isn't set. */
    STREAK_THRESHOLD_VALUE_REQUIRED,

    /** A goal without sessions, other than a tracker, has no target. */
    TARGET_REQUIRED,
}

/** The outcome of [GoalDefinition.create]: the goal, or every reason it's invalid. */
public sealed interface GoalDefinitionResult {
    public data class Valid(val definition: GoalDefinition) : GoalDefinitionResult

    public data class Invalid(val errors: Set<GoalDefinitionError>) : GoalDefinitionResult {
        init {
            require(errors.isNotEmpty()) { "An invalid goal has at least one error" }
        }
    }
}

/**
 * The validity rules of the schema's `goal`. The count policies that count are the goal's when it has
 * no sessions, and each session's when it has some (the goal's own policy is then unused).
 */
internal fun validityErrors(
    countPolicy: CountPolicy,
    sessions: List<Session>,
    requirement: Requirement,
): Set<GoalDefinitionError> {
    val policies = if (sessions.isEmpty()) listOf(countPolicy) else sessions.map { it.countPolicy }
    val missingTarget = when {
        sessions.isEmpty() -> GoalDefinitionError.TARGET_REQUIRED
        else -> GoalDefinitionError.SESSION_TARGET_REQUIRED
    }
    return buildSet {
        if (requirement != Requirement.Tracker && policies.any { it.target == null }) add(missingTarget)
        if (!policies.all { it.hasStreakThresholdValue }) add(GoalDefinitionError.STREAK_THRESHOLD_VALUE_REQUIRED)
    }
}
