package app.awrad.core.domain.goal.rules

import app.awrad.core.domain.goal.CountEntry
import app.awrad.core.domain.goal.GoalTimeline
import app.awrad.core.domain.goal.Requirement
import app.awrad.core.domain.hijri.HijriCalendar
import app.awrad.core.domain.hijri.HijriCorrections
import java.time.LocalDate
import java.time.YearMonth

/** Why a day can't be excused or un-excused (fixture `excused_days`). */
public enum class ExcuseRefusal {
    /** The goal has ended, or is past its last day. */
    GOAL_FINISHED,

    /** Only days before today can be excused. */
    NOT_PAST,
    ALREADY_EXCUSED,

    /** Period totals aren't judged by day. */
    NOT_AVAILABLE,

    /** Off-schedule, paused or outside the active period. */
    NOT_DUE,

    /** It was kept (met, minimum only or made up; for days per period, it qualified). */
    NOT_MISSED,

    /** Two days are already excused in that day's Gregorian month. */
    LIMIT_REACHED,

    /** Un-excusing a day that isn't excused. */
    NOT_EXCUSED,
}

/**
 * Rule: why [day] can't be excused on [today], or null when it can (fixture `excused_days`; decision 20). Checked in
 * order: the goal still runs, the day is before today, isn't excused already, the goal is judged by day, the day is
 * due and wasn't kept (a day pending make-up can be excused), and fewer than 2 days are excused in its month.
 */
public fun GoalTimeline.excuseRefusal(
    day: LocalDate,
    today: LocalDate,
    counts: List<CountEntry>,
    hijriCorrections: HijriCorrections,
): ExcuseRefusal? {
    val days = GoalDays(this, CountIndex(counts), HijriCalendar(hijriCorrections))
    return when {
        isFinishedOn(today) -> ExcuseRefusal.GOAL_FINISHED
        !day.isBefore(today) -> ExcuseRefusal.NOT_PAST
        day in excused -> ExcuseRefusal.ALREADY_EXCUSED
        days.goalOn(today).requirement is Requirement.PeriodTotal -> ExcuseRefusal.NOT_AVAILABLE
        !days.isDue(day) -> ExcuseRefusal.NOT_DUE
        days.wasKept(day, today) -> ExcuseRefusal.NOT_MISSED
        excused.count { YearMonth.from(it) == YearMonth.from(day) } >= EXCUSED_PER_MONTH -> ExcuseRefusal.LIMIT_REACHED
        else -> null
    }
}

/** Met, minimum only or made up as of [today]; for days per period, a day that qualified. */
private fun GoalDays.wasKept(day: LocalDate, today: LocalDate): Boolean {
    val goal = goalOn(day)
    return if (goal.requirement is Requirement.DaysPerPeriod) {
        goal.dayMeetsTarget(day, counts)
    } else {
        statusesOn(today)[day]?.status?.isKept == true
    }
}

/** Rule: why [day] can't be un-excused on [today], or null when it can; un-excusing frees its place in the month. */
public fun GoalTimeline.unexcuseRefusal(day: LocalDate, today: LocalDate): ExcuseRefusal? = when {
    isFinishedOn(today) -> ExcuseRefusal.GOAL_FINISHED
    day !in excused -> ExcuseRefusal.NOT_EXCUSED
    else -> null
}

private fun GoalTimeline.isFinishedOn(today: LocalDate): Boolean =
    ended != null || goalOn(today).activePeriod.lastDay?.let { today.isAfter(it) } == true

/** At most 2 excused days per goal per Gregorian month (decision 20). */
public const val EXCUSED_PER_MONTH: Int = 2
