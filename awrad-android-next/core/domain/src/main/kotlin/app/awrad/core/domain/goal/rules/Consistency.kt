package app.awrad.core.domain.goal.rules

import app.awrad.core.domain.goal.CountEntry
import app.awrad.core.domain.goal.GoalTimeline
import app.awrad.core.domain.hijri.HijriCalendar
import app.awrad.core.domain.hijri.HijriCorrections
import app.awrad.core.domain.practice.WeekStart
import java.time.LocalDate

/** What consistency is measured over: due days (units day, weekday, occasion) or periods (weeks, months). */
public enum class ConsistencyBasis {
    DUE_DAYS,
    PERIODS,
}

/** The gentle tag a row shows when its streak breaks (decision 19). */
public enum class ConsistencyTag {
    /** 90% or more. */
    DEVOTED,

    /** 80% or more. */
    STEADY,
}

/** What a goal's row shows (README.md, "Consistency"). */
public enum class RowBadge {
    STREAK,
    CONSISTENCY,
    NONE,
}

/** [met] of the last [outOf] due days or periods, the [tag] that earns, and what the row [show]s. */
public data class Consistency(
    val basis: ConsistencyBasis,
    val met: Int,
    val outOf: Int,
    val tag: ConsistencyTag?,
    val show: RowBadge,
)

/**
 * Rule: consistency on [date] (fixture `consistency`; decisions 19, 21 and 32).
 *
 * - Daily-rhythm goals count the due days that kept the streak among the last 30; period goals the met periods among
 *   the last 12. Today, or the current period, counts only once kept or met, and a day pending make-up only once its
 *   window closes.
 * - No tag before 7 due days or 4 periods; then Devoted at 90% or more, Steady at 80% or more.
 * - The row shows the streak from 3, else the tag, else a streak of 1 or 2, else nothing.
 */
public fun GoalTimeline.consistencyOn(
    date: LocalDate,
    counts: List<CountEntry>,
    weekStart: WeekStart,
    hijriCorrections: HijriCorrections,
): Consistency {
    val days = GoalDays(this, CountIndex(counts), HijriCalendar(hijriCorrections))
    val periodic = days.goalOn(date).streakUnit.let { it == StreakUnit.WEEK || it == StreakUnit.MONTH }
    val settled: List<Boolean> = if (periodic) {
        days.periodsBack(date, weekStart)
            .filterNot { it.isInProgress && !it.isMet }
            .take(PERIOD_WINDOW)
            .map { it.isMet }
            .toList()
    } else {
        days.statusesOn(date).values.reversed()
            .filterNot { it.status.isOpen }
            .take(DUE_DAY_WINDOW)
            .map { it.status.isKept }
    }
    val met = settled.count { it }
    val outOf = settled.size
    val enough = outOf >= if (periodic) MIN_PERIODS else MIN_DUE_DAYS
    val tag = when {
        !enough -> null
        met * PERCENT >= outOf * DEVOTED_PERCENT -> ConsistencyTag.DEVOTED
        met * PERCENT >= outOf * STEADY_PERCENT -> ConsistencyTag.STEADY
        else -> null
    }
    val streak = days.streakOn(date, weekStart)
    val show = when {
        streak >= STREAK_FIRST -> RowBadge.STREAK
        tag != null -> RowBadge.CONSISTENCY
        streak >= 1 -> RowBadge.STREAK
        else -> RowBadge.NONE
    }
    return Consistency(if (periodic) ConsistencyBasis.PERIODS else ConsistencyBasis.DUE_DAYS, met, outOf, tag, show)
}

private const val DUE_DAY_WINDOW = 30
private const val PERIOD_WINDOW = 12
private const val MIN_DUE_DAYS = 7
private const val MIN_PERIODS = 4
private const val PERCENT = 100
private const val DEVOTED_PERCENT = 90
private const val STEADY_PERCENT = 80

/** A streak this long shows instead of the consistency tag (decision 21). */
private const val STREAK_FIRST = 3
