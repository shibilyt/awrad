package app.awrad.core.domain.goal.rules

import app.awrad.core.domain.goal.CalendarPeriod
import app.awrad.core.domain.goal.CountEntry
import app.awrad.core.domain.goal.DateWindow
import app.awrad.core.domain.goal.GoalDefinition
import app.awrad.core.domain.goal.GoalTimeline
import app.awrad.core.domain.goal.Requirement
import app.awrad.core.domain.goal.Schedule
import app.awrad.core.domain.hijri.HijriCalendar
import app.awrad.core.domain.hijri.HijriCorrections
import app.awrad.core.domain.practice.WeekStart
import java.time.DayOfWeek
import java.time.LocalDate

/** What a streak counts, in the goal's own rhythm (decision 43). */
public enum class StreakUnit {
    /** Due days: 🔥 15 days. */
    DAY,

    /** Due days of a single-weekday schedule: 🔥 12 Fridays. */
    WEEKDAY,

    /** Weeks meeting a weekly total or "N days a week". */
    WEEK,

    /** Months (Gregorian or Hijri) meeting a monthly requirement. */
    MONTH,

    /** Occasions of a yearly schedule whose every due day kept the streak: 🔥 2 Ramadans. */
    OCCASION,
}

/**
 * The current streak: [current] [unit]s ([weekday] for [StreakUnit.WEEKDAY]), and the days pending make-up, so a row
 * can read "🔥 15 · make up Mon" ([pendingMakeUp], oldest first).
 */
public data class Streak(
    val current: Int,
    val unit: StreakUnit,
    val weekday: DayOfWeek?,
    val pendingMakeUp: List<LocalDate>,
)

/**
 * Rule: the current streak on [date] (fixture `goal_streak`), counting back from [date], each day judged by its own
 * version and the unit by the version in force on [date].
 *
 * - Days and weekdays: due days that kept the streak (met, minimum only or made up). Today and days pending make-up
 *   are open: they neither break nor add; any other day breaks it.
 * - Weeks and months: periods meeting the requirement, each judged by the version on its last day so far. The current
 *   period never breaks it while the goal runs. Periods without due days (or needing none) are skipped.
 * - Occasions: occasions whose every due day kept the streak. The current one doesn't break it while in progress, and
 *   adds only once complete.
 *
 * Hijri schedules and Hijri months read [hijriCorrections].
 */
public fun GoalTimeline.streakOn(
    date: LocalDate,
    counts: List<CountEntry>,
    weekStart: WeekStart,
    hijriCorrections: HijriCorrections,
): Streak {
    val days = GoalDays(this, CountIndex(counts), HijriCalendar(hijriCorrections))
    val goal = days.goalOn(date)
    val unit = goal.streakUnit
    return Streak(
        current = days.streakOn(date, weekStart),
        unit = unit,
        weekday = if (unit == StreakUnit.WEEKDAY) (goal.schedule as Schedule.Weekdays).days.single() else null,
        pendingMakeUp = days.statusesOn(date).values.filter { it.status == DayStatus.PENDING }.map { it.date },
    )
}

/** The streak unit (README.md, "Streaks"). */
internal val GoalDefinition.streakUnit: StreakUnit
    get() {
        val schedule = schedule
        return when {
            period != null -> if (period == CalendarPeriod.WEEK) StreakUnit.WEEK else StreakUnit.MONTH
            schedule is Schedule.Yearly -> StreakUnit.OCCASION
            schedule is Schedule.Weekdays && schedule.days.size == 1 -> StreakUnit.WEEKDAY
            else -> StreakUnit.DAY
        }
    }

/** The period a period total or days-per-period goal is judged in; null for other requirements. */
internal val GoalDefinition.period: CalendarPeriod?
    get() = when (val requirement = requirement) {
        is Requirement.PeriodTotal -> requirement.period
        is Requirement.DaysPerPeriod -> requirement.period
        else -> null
    }

internal fun GoalDays.streakOn(today: LocalDate, weekStart: WeekStart): Int {
    val units = when (goalOn(today).streakUnit) {
        StreakUnit.WEEK, StreakUnit.MONTH -> periodsBack(today, weekStart)
            .map { StreakStep(isOpen = it.isInProgress && !it.isMet, isKept = it.isMet) }
        StreakUnit.OCCASION -> occasionsBack(today).asSequence()
            .map { StreakStep(isOpen = it.isInProgress, isKept = it.isKept) }
        StreakUnit.DAY, StreakUnit.WEEKDAY -> statusesOn(today).values.reversed().asSequence()
            .map { StreakStep(isOpen = it.status.isOpen, isKept = it.status.isKept) }
    }
    return units.filterNot { it.isOpen }.takeWhile { it.isKept }.count()
}

/** One unit counting back: open units (in progress, pending) neither add nor break; kept ones add; others break. */
private data class StreakStep(val isOpen: Boolean, val isKept: Boolean)

/** A week or month with due days, judged as of today. */
internal data class PeriodStanding(val window: DateWindow, val isInProgress: Boolean, val isMet: Boolean)

/** The goal's periods with due days, newest first, as of [today]. */
internal fun GoalDays.periodsBack(today: LocalDate, weekStart: WeekStart): Sequence<PeriodStanding> {
    val goal = goalOn(today)
    val period = checkNotNull(goal.period) { "Not a period goal: ${goal.requirement}" }
    val last = lastDay(today)?.let { minOf(today, it) } ?: today
    if (last.isBefore(startDate)) return emptySequence()
    return PeriodCalendar(weekStart, hijri).periodsBack(last, period)
        .map { goal.activePeriod.clip(it) }
        .takeWhile { it != null }
        .filterNotNull()
        .filter { window -> window.days().any(::isDue) && requiredDays(window, today) > 0 }
        .map { PeriodStanding(it, isInProgress = !it.to.isBefore(today), isMet = isMet(it, today)) }
}

private fun GoalDays.requiredDays(window: DateWindow, today: LocalDate): Int =
    if (goalOn(today).requirement is Requirement.DaysPerPeriod) tally(window, today).required else 1

/** Whether [window] meets the requirement of the version in force on its last day so far. */
private fun GoalDays.isMet(window: DateWindow, today: LocalDate): Boolean {
    val goal = goalOn(minOf(window.to, today))
    if (goal.requirement is Requirement.DaysPerPeriod) return tally(window, today).let { it.qualifying >= it.required }
    val days = window.days().filter { !it.isAfter(today) && it in goal.activePeriod }.toList()
    return goal.isMetBy(goal.progressOver(days, counts))
}

/** One occasion of a yearly goal: its due days so far, newest first. */
internal data class Occasion(val year: Int, val days: List<DueDay>, val isInProgress: Boolean) {
    val isKept: Boolean get() = days.all { it.status.isKept }
}

/** The goal's occasions, newest first, as of [today]. */
internal fun GoalDays.occasionsBack(today: LocalDate): List<Occasion> {
    val groups = mutableListOf<Pair<Int, MutableList<DueDay>>>()
    statusesOn(today).values.reversed().forEach { day ->
        val year = occasionYear(day.date)
        if (groups.lastOrNull()?.first == year) groups.last().second += day else groups += year to mutableListOf(day)
    }
    return groups.mapIndexed { index, (year, days) ->
        val isLatest = index == 0 && isRunning(today)
        val isInProgress = isLatest && (days.any { it.status.isOpen } || nextOccasionYear(today) == year)
        Occasion(year, days, isInProgress)
    }
}

private fun GoalDays.occasionYear(date: LocalDate): Int {
    val schedule = goalOn(date).schedule as Schedule.Yearly
    return checkNotNull(schedule.matchOn(date, hijri)) { "$date isn't an occasion day" }.occasionYear
}

/** The occasion of the next scheduled, unpaused day after [today] (within the horizon), or null when there's none. */
private fun GoalDays.nextOccasionYear(today: LocalDate): Int? {
    val next = daysBetween(today.plusDays(1), today.plusDays(HORIZON_DAYS))
        .takeWhile { day -> lastDay(day)?.let { !day.isAfter(it) } ?: true }
        .firstOrNull { isScheduled(it) && !goalOn(it).isPausedOn(it) }
    return next?.let(::occasionYear)
}

/** How far ahead rules look for a goal's next scheduled day (README.md, "Placement"). */
internal const val HORIZON_DAYS: Long = 400
