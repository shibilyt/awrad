package app.awrad.core.domain.goal

import app.awrad.core.domain.AwradId
import java.time.LocalDate

/**
 * A single measurable objective attached to one dhikr (see CONTEXT.md).
 * This slice only models the every-day Requirement created during onboarding.
 */
public data class Goal(
    val id: AwradId,
    val dhikrCatalogKey: String,
    val dailyTarget: DailyTarget,
    val startDate: LocalDate,
)

/** How many counts a day satisfies the Requirement. Always within [MIN]..[MAX]. */
@JvmInline
public value class DailyTarget private constructor(public val count: Int) {

    public operator fun plus(delta: Int): DailyTarget = of(count + delta)

    public val canDecrease: Boolean get() = count > MIN
    public val canIncrease: Boolean get() = count < MAX

    public companion object {
        public const val MIN: Int = 1
        public const val MAX: Int = 100_000

        /** Clamps instead of failing: a stepper or chip can never produce an invalid target. */
        public fun of(count: Int): DailyTarget = DailyTarget(count.coerceIn(MIN, MAX))
    }
}

/** Port: goal persistence. Adapters own transactions and sync bookkeeping. */
public interface GoalRepository {
    public suspend fun add(goal: Goal)
}
