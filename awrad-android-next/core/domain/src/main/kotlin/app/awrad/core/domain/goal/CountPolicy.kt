package app.awrad.core.domain.goal

import app.awrad.core.domain.AwradId
import java.time.Instant
import java.time.LocalDate

/**
 * Which number a day must reach to keep the streak (README.md, "Streaks"): any count (1), the count policy's minimum,
 * target or maximum, a number of its own ([Amount], decisions 29 and 36), or [DailyPace], that day's pace share
 * (totals with an end only).
 */
public sealed interface StreakThreshold {
    public data object AnyCount : StreakThreshold

    public data object Minimum : StreakThreshold

    public data object Target : StreakThreshold

    public data object Maximum : StreakThreshold

    public data object DailyPace : StreakThreshold

    public data class Amount(val amount: Long) : StreakThreshold {
        init {
            require(amount >= 1) { "A streak amount is at least 1: $amount" }
        }
    }
}

/**
 * The numbers a goal works against (CONTEXT.md, "Count policy"). Counts are whole numbers.
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

    /** The value a minimum, target or maximum threshold points at; null for the others or when it isn't set. */
    internal val streakThresholdValue: Long?
        get() = when (streakThreshold) {
            StreakThreshold.Minimum -> minimum
            StreakThreshold.Target -> target
            StreakThreshold.Maximum -> maximum
            StreakThreshold.AnyCount, StreakThreshold.DailyPace, is StreakThreshold.Amount -> null
        }

    /** Whether the value the streak threshold points at is set. A valid goal's policy always has it. */
    internal val hasStreakThresholdValue: Boolean
        get() = when (streakThreshold) {
            StreakThreshold.Minimum, StreakThreshold.Target, StreakThreshold.Maximum -> streakThresholdValue != null
            StreakThreshold.AnyCount, StreakThreshold.DailyPace, is StreakThreshold.Amount -> true
        }
}

/** How long after a missed day it can still be made up, in practice days. */
public enum class MakeUpWindow(public val days: Int) {
    OFF(0),
    NEXT_DAY(1),

    @Suppress("MagicNumber") // The name says it.
    WITHIN_3_DAYS(3),
}

/** How much a missed day needs to count as made up: its streak amount, or its target (or streak amount if higher). */
public enum class MakeUpFill {
    STREAK,
    TARGET,
}

/** Make-up (qada; README.md, "Make-up"; decisions 18, 31 and 48). [fill] is kept while [window] is off. */
public data class MakeUp(val window: MakeUpWindow, val fill: MakeUpFill = MakeUpFill.STREAK) {
    public companion object {
        public val OFF: MakeUp = MakeUp(MakeUpWindow.OFF)
    }
}

/**
 * A day's total for the goal ([sessionId] null) or for one session, on an effective practice day.
 * [attributedCounts] makes them from the count log.
 */
public data class CountEntry(val date: LocalDate, val sessionId: String?, val count: Long) {
    init {
        require(count >= 0) { "Counts can't be negative: $count" }
    }
}

/**
 * One entry of a profile's append-only count log (`$defs/count_log_entry`; decisions 1, 2, 5 and 38). Counts belong to
 * the dhikr: [goalId] is set only for a count made in a dedicated goal. [amount] is never 0, and negative for an
 * adjustment or an undo. [id] is a UUIDv7 made where the count was made.
 */
public data class CountLogEntry(
    val id: AwradId,
    val dhikrId: AwradId,
    val practiceDay: LocalDate,
    val sessionId: String?,
    val goalId: AwradId?,
    val amount: Long,
    val countedAt: Instant,
) {
    init {
        require(amount != 0L) { "A count log entry's amount is never 0" }
    }
}
