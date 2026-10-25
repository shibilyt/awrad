package app.awrad.core.domain.goal

import java.time.LocalDate

/** Which count policy value a day must reach to count toward the streak. */
public enum class StreakThreshold {
    ANY_COUNT,
    MINIMUM,
    TARGET,
    MAXIMUM,
}

/**
 * The numbers a goal or session works against (CONTEXT.md, "Count policy"). Counts are whole numbers.
 */
public data class CountPolicy(
    val minimum: Long? = null,
    val target: Long?,
    val maximum: Long? = null,
    val streakThreshold: StreakThreshold,
) {
    init {
        require(listOfNotNull(minimum, target, maximum).all { it >= 0 }) { "Counts can't be negative: $this" }
    }

    /** Whether [count] meets the target. Without a target (a tracker), any positive count does. */
    public fun meetsTarget(count: Long): Boolean = target?.let { count >= it } ?: (count > 0)

    /** Whether [count] meets the streak threshold. A threshold whose value is missing can never be met. */
    public fun meetsStreakThreshold(count: Long): Boolean {
        val threshold = when (streakThreshold) {
            StreakThreshold.ANY_COUNT -> return count > 0
            StreakThreshold.MINIMUM -> minimum
            StreakThreshold.TARGET -> target
            StreakThreshold.MAXIMUM -> maximum
        }
        return threshold != null && count >= threshold
    }
}

/** A time-of-day opportunity for a goal, with its own count policy (CONTEXT.md, "Session"). */
public data class Session(val id: String, val countPolicy: CountPolicy) {
    init {
        require(id.isNotBlank()) { "A session needs an id" }
    }
}

/**
 * A day's total for the goal ([sessionId] null) or for one session, on an effective practice day.
 */
public data class CountEntry(val date: LocalDate, val sessionId: String?, val count: Long) {
    init {
        require(count >= 0) { "Counts can't be negative: $count" }
    }
}
