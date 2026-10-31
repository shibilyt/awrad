package app.awrad.core.domain.goal.rules

import app.awrad.core.domain.goal.CountEntry
import app.awrad.core.domain.goal.GoalTimeline
import app.awrad.core.domain.goal.MakeUpFill
import app.awrad.core.domain.goal.MakeUpWindow
import app.awrad.core.domain.hijri.HijriCalendar
import app.awrad.core.domain.hijri.HijriCorrections
import java.time.LocalDate
import java.time.temporal.ChronoUnit

/**
 * A due day's status (README.md, "Streaks" and "Make-up"). Declared worst first: a day with sessions takes the worst of
 * its sessions' statuses.
 */
public enum class DayStatus {
    /** Today, not kept yet. */
    IN_PROGRESS,
    MISSED,

    /** Not kept, but its make-up window is still open (decision 46). */
    PENDING,

    /** Filled by make-up to its fill amount. */
    MADE_UP,

    /** At least the streak amount, below the target. */
    MINIMUM_ONLY,

    /** At least its target and its streak amount. */
    MET,
    ;

    /** Met, minimum only or made up: the day keeps the streak. */
    public val isKept: Boolean get() = this == MET || this == MINIMUM_ONLY || this == MADE_UP

    /** Today or pending: not settled yet, so it neither breaks nor adds to a streak. */
    public val isOpen: Boolean get() = this == IN_PROGRESS || this == PENDING
}

/** One due day: its own [count], what make-up [filled] in from later days, and its [status]. */
public data class DueDay(val date: LocalDate, val count: Long, val filled: Long, val status: DayStatus)

/**
 * Rule: every due day's status from the start date up to [today] (or the goal's last day), oldest first (fixture
 * `make_up`). Each day is judged by its own version.
 *
 * Make-up: counts past what a later day needs for itself (its target, or its streak amount if higher; all of a day
 * that isn't due; nothing on paused or excused days or after the end) fill missed days inside their window, oldest
 * first, each up to its fill amount. With sessions, each session fills only itself. Make-up is derived from the
 * counts, never stored.
 */
public fun GoalTimeline.dueDaysOn(
    today: LocalDate,
    counts: List<CountEntry>,
    hijriCorrections: HijriCorrections,
): List<DueDay> = GoalDays(this, CountIndex(counts), HijriCalendar(hijriCorrections)).statusesOn(today).values.toList()

/** One unit of a due day (the day, or a session) while make-up is worked out. */
private class UnitTally(
    val sessionId: String?,
    val target: Long?,
    val streak: Long,
    val count: Long,
    val fillAmount: Long,
) {
    var filled: Long = 0

    /** What this day has past its own needs, which it gives to earlier missed days. */
    val surplus: Long get() = maxOf(0, count - maxOf(target ?: 0, streak))

    val deficit: Long get() = fillAmount - count - filled

    fun status(date: LocalDate, today: LocalDate, isPendingIfMissed: Boolean): DayStatus = when {
        count >= streak && (target == null || count >= target) -> DayStatus.MET
        filled > 0 && count + filled >= fillAmount -> DayStatus.MADE_UP
        count >= streak -> DayStatus.MINIMUM_ONLY
        date == today -> DayStatus.IN_PROGRESS
        isPendingIfMissed -> DayStatus.PENDING
        else -> DayStatus.MISSED
    }
}

private class DueDayTally(val date: LocalDate, val window: Int, val units: List<UnitTally>)

/** The statuses [GoalDays.statusesOn] caches. */
internal fun GoalDays.dayStatuses(today: LocalDate): Map<LocalDate, DueDay> {
    val due = daysUpTo(today).filter(::isDue).associateWith(::tallyOn)
    daysUpTo(today).forEach { giveSurplus(it, due) }
    val running = isRunning(today)
    return due.mapValues { (date, day) ->
        // Still inside its make-up window, while the goal runs: pending rather than missed.
        val open = day.window > 0 && !today.isAfter(date.plusDays(day.window.toLong())) && running
        DueDay(
            date = date,
            count = day.units.sumOf { it.count },
            filled = day.units.sumOf { it.filled },
            status = day.units.minOf { it.status(date, today, open) },
        )
    }
}

private fun GoalDays.tallyOn(date: LocalDate): DueDayTally {
    val goal = goalOn(date)
    val units = goal.units.map { unit ->
        val target = goal.dailyTarget(unit.policy)
        val streak = streakAmount(unit.policy, date)
        val fillAmount = when (goal.makeUp.fill) {
            MakeUpFill.STREAK -> streak
            MakeUpFill.TARGET -> maxOf(target ?: 0, streak)
        }
        UnitTally(unit.sessionId, target, streak, goal.countOf(unit, date, counts), fillAmount)
    }
    return DueDayTally(date, goal.makeUp.window.days, units)
}

/** [day]'s counts past its own needs fill the missed days whose window reaches it, oldest first. */
private fun GoalDays.giveSurplus(day: LocalDate, due: Map<LocalDate, DueDayTally>) {
    val goal = goalOn(day)
    if (day !in goal.activePeriod || goal.isPausedOn(day) || day in goal.excused) return
    val own = due[day]
    val surplus = HashMap<String?, Long>()
    fun surplusOf(sessionId: String?): Long = surplus.getOrPut(sessionId) {
        when {
            own != null -> own.units.firstOrNull { it.sessionId == sessionId }?.surplus ?: 0
            sessionId != null -> counts.session(day, sessionId)
            else -> counts.all(day)
        }
    }
    val reached = (MAX_WINDOW downTo 1).mapNotNull { back ->
        due[day.minusDays(back.toLong())]?.takeIf { ChronoUnit.DAYS.between(it.date, day) <= it.window }
    }
    reached.forEach { missed ->
        missed.units.filter { it.deficit > 0 }.forEach { unit ->
            val give = minOf(unit.deficit, surplusOf(unit.sessionId))
            unit.filled += give
            surplus[unit.sessionId] = surplusOf(unit.sessionId) - give
        }
    }
}

private val MAX_WINDOW = MakeUpWindow.entries.maxOf { it.days }
