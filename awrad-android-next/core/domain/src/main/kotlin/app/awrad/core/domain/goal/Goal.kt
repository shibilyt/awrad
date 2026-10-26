package app.awrad.core.domain.goal

import app.awrad.core.domain.AwradId

/**
 * A single measurable objective attached to one dhikr or tracked amal (CONTEXT.md, "Goal").
 * Identity lives here; everything the goal rules read lives in [definition].
 */
public data class Goal(
    val id: AwradId,
    val dhikrCatalogKey: String,
    val definition: GoalDefinition,
)

/**
 * What a goal asks for: the shape of `goal` in `contracts/goal-model/v1/goal-model.schema.json`.
 * The rules in `app.awrad.core.domain.goal.rules` evaluate it.
 *
 * Only valid goals exist (CONTEXT.md, "Count policy"). Build one with [create], which returns every
 * [GoalDefinitionError] instead of an invalid goal; creation, sync and import all go through it.
 */
@ConsistentCopyVisibility
public data class GoalDefinition private constructor(
    val schedule: Schedule,
    val activePeriod: ActivePeriod,
    val paused: List<PausedRange>,
    val countPolicy: CountPolicy,
    val sessions: List<Session>,
    val requirement: Requirement,
    val completion: CompletionPolicy,
) {
    init {
        require(sessions.map { it.id }.toSet().size == sessions.size) { "Session ids must be unique" }
    }

    public companion object {
        /**
         * Validates the parts and builds the goal, or returns why it's invalid (fixture `goal_validity`).
         * Structural mistakes still throw: duplicate session ids, and the shapes each part rejects itself.
         */
        @Suppress("LongParameterList") // One parameter per field of the contract's goal.
        public fun create(
            schedule: Schedule,
            activePeriod: ActivePeriod,
            paused: List<PausedRange> = emptyList(),
            countPolicy: CountPolicy,
            sessions: List<Session> = emptyList(),
            requirement: Requirement,
            completion: CompletionPolicy = CompletionPolicy.NEVER,
        ): GoalDefinitionResult {
            val errors = validityErrors(countPolicy, sessions, requirement)
            return if (errors.isEmpty()) {
                GoalDefinitionResult.Valid(
                    GoalDefinition(schedule, activePeriod, paused, countPolicy, sessions, requirement, completion),
                )
            } else {
                GoalDefinitionResult.Invalid(errors)
            }
        }
    }
}

/** Port: goal persistence. Adapters own transactions and sync bookkeeping. */
public interface GoalRepository {
    public suspend fun add(goal: Goal)
}
