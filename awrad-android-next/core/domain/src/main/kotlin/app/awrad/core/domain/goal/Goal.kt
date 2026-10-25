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
 */
public data class GoalDefinition(
    val schedule: Schedule,
    val activePeriod: ActivePeriod,
    val paused: List<PausedRange> = emptyList(),
    val countPolicy: CountPolicy,
    val sessions: List<Session> = emptyList(),
    val requirement: Requirement,
    val completion: CompletionPolicy = CompletionPolicy.NEVER,
) {
    init {
        require(sessions.map { it.id }.toSet().size == sessions.size) { "Session ids must be unique" }
    }
}

/** Port: goal persistence. Adapters own transactions and sync bookkeeping. */
public interface GoalRepository {
    public suspend fun add(goal: Goal)
}
