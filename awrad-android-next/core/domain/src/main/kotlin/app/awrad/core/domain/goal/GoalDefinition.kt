package app.awrad.core.domain.goal

import java.time.LocalDate

/**
 * What a dated version holds (`$defs/goal_settings_shape`): everything a goal is judged by except its pauses and
 * excused days, which belong to the whole goal. Unvalidated on its own: [GoalDefinition.create] and
 * [GoalTimeline.create] check it.
 */
public data class GoalSettings(
    val schedule: Schedule,
    val activePeriod: ActivePeriod,
    val countPolicy: CountPolicy,
    val sessions: List<Session> = emptyList(),
    val requirement: Requirement,
    val completion: CompletionPolicy = CompletionPolicy.NEVER,
    val makeUp: MakeUp = MakeUp.OFF,
)

/**
 * What a rule evaluates on one day: the shape of `goal` in `contracts/goal-model/v1/goal-model.schema.json`, one
 * version's [settings] plus the goal's [paused] ranges and [excused] days. The rules in
 * `app.awrad.core.domain.goal.rules` evaluate it, or a [GoalTimeline] day by day.
 *
 * Only valid goals exist (CONTEXT.md, "Count policy"). Build one with [create], which returns every
 * [GoalDefinitionError] instead of an invalid goal; creation, sync and import all go through it.
 */
@ConsistentCopyVisibility
public data class GoalDefinition internal constructor(
    val settings: GoalSettings,
    val paused: List<PausedRange>,
    val excused: Set<LocalDate>,
) {
    val schedule: Schedule get() = settings.schedule
    val activePeriod: ActivePeriod get() = settings.activePeriod
    val countPolicy: CountPolicy get() = settings.countPolicy
    val sessions: List<Session> get() = settings.sessions
    val requirement: Requirement get() = settings.requirement
    val completion: CompletionPolicy get() = settings.completion
    val makeUp: MakeUp get() = settings.makeUp

    public companion object {
        /** Validates [settings] and builds the goal, or returns why it's invalid (fixture `goal_validity`). */
        public fun create(
            settings: GoalSettings,
            paused: List<PausedRange> = emptyList(),
            excused: Set<LocalDate> = emptySet(),
        ): GoalDefinitionResult {
            val errors = settings.validityErrors()
            return if (errors.isEmpty()) {
                GoalDefinitionResult.Valid(GoalDefinition(settings, paused, excused))
            } else {
                GoalDefinitionResult.Invalid(errors)
            }
        }
    }
}
