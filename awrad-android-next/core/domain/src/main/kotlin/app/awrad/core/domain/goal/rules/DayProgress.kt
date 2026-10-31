package app.awrad.core.domain.goal.rules

import app.awrad.core.domain.goal.CalendarPeriod
import app.awrad.core.domain.goal.CountEntry
import app.awrad.core.domain.goal.CountPolicy
import app.awrad.core.domain.goal.DateWindow
import app.awrad.core.domain.goal.GoalDefinition
import app.awrad.core.domain.goal.Requirement
import app.awrad.core.domain.goal.Session
import app.awrad.core.domain.goal.StreakThreshold
import app.awrad.core.domain.hijri.HijriCalendar
import app.awrad.core.domain.practice.WeekStart
import java.time.LocalDate
import java.time.temporal.TemporalAdjusters

/** Count entries summed by day and session, so rules that walk many days look each one up once. */
internal class CountIndex(entries: List<CountEntry>) {
    private val byDate: Map<LocalDate, Map<String?, Long>> = entries
        .groupBy { it.date }
        .mapValues { (_, day) -> day.groupBy { it.sessionId }.mapValues { (_, entries) -> entries.sumOf { it.count } } }

    /** Every entry on [date], whichever session it belongs to. */
    fun all(date: LocalDate): Long = byDate[date]?.values?.sum() ?: 0

    fun session(date: LocalDate, sessionId: String): Long = byDate[date]?.get(sessionId) ?: 0

    companion object {
        val EMPTY = CountIndex(emptyList())
    }
}

/** The goal's count on [date]: every entry without sessions; with sessions, only its sessions' entries. */
internal fun GoalDefinition.countOn(date: LocalDate, counts: CountIndex): Long =
    if (sessions.isEmpty()) counts.all(date) else sessions.sumOf { counts.session(date, it.id) }

/** What a day is judged in: the whole goal ([sessionId] null), or each session, with the policy it's judged by. */
internal data class DayUnit(val sessionId: String?, val policy: CountPolicy)

internal val GoalDefinition.units: List<DayUnit>
    get() = if (sessions.isEmpty()) listOf(DayUnit(null, countPolicy)) else sessions.map { DayUnit(it.id, it.policy) }

/** A session has a target only: its streak amount is that target, or any count for a tracker's session without one. */
internal val Session.policy: CountPolicy
    get() = CountPolicy(
        target = target,
        streakThreshold = if (target == null) StreakThreshold.AnyCount else StreakThreshold.Target,
    )

internal fun GoalDefinition.countOf(unit: DayUnit, date: LocalDate, counts: CountIndex): Long =
    unit.sessionId?.let { counts.session(date, it) } ?: countOn(date, counts)

/** The target a single day must reach: per due date and days per period have one, other requirements don't. */
internal fun GoalDefinition.dailyTarget(policy: CountPolicy): Long? = when (requirement) {
    Requirement.PerDueDate, is Requirement.DaysPerPeriod -> policy.target
    else -> null
}

/** Whether [count] meets [policy]'s target; a tracker's target is ignored, so any count does. */
internal fun GoalDefinition.meetsTarget(policy: CountPolicy, count: Long): Boolean =
    if (requirement == Requirement.Tracker) count > 0 else policy.meetsTarget(count)

/** Whether one day meets the daily target (with sessions, each session its own): days per period's qualifying day. */
internal fun GoalDefinition.dayMeetsTarget(date: LocalDate, counts: CountIndex): Boolean =
    units.all { meetsTarget(it.policy, countOf(it, date, counts)) }

/** Progress over some days: the goal's total, and each session's against its own target. */
internal data class Progress(val total: Long, val sessions: List<SessionStanding>)

internal fun GoalDefinition.progressOver(days: List<LocalDate>, counts: CountIndex): Progress = Progress(
    total = days.sumOf { countOn(it, counts) },
    sessions = sessions.map { session ->
        val progress = days.sumOf { counts.session(it, session.id) }
        SessionStanding(session.id, progress, session.target, session.policy.meetsTarget(progress))
    },
)

/** Whether [progress] meets the requirement's target: the goal's, or every session's own. */
internal fun GoalDefinition.isMetBy(progress: Progress): Boolean =
    if (sessions.isEmpty()) meetsTarget(countPolicy, progress.total) else progress.sessions.all { it.isMet }

/** The calendar periods rules group days into: weeks start on [weekStart], Hijri months follow [hijri]. */
internal data class PeriodCalendar(val weekStart: WeekStart, val hijri: HijriCalendar) {

    /**
     * The whole week, month or Hijri month containing [date], before clipping to the active period.
     * Null for a Hijri month outside the Hijri table, which is never due.
     */
    fun periodOf(date: LocalDate, period: CalendarPeriod): DateWindow? = when (period) {
        CalendarPeriod.WEEK -> {
            val from = date.with(TemporalAdjusters.previousOrSame(weekStart.firstDay))
            DateWindow(from, from.plusDays(DAYS_IN_WEEK - 1))
        }
        CalendarPeriod.MONTH -> DateWindow(date.withDayOfMonth(1), date.with(TemporalAdjusters.lastDayOfMonth()))
        CalendarPeriod.HIJRI_MONTH -> hijri.monthOf(date)?.let { DateWindow(it.firstDay, it.lastDay) }
    }

    /**
     * Every [period] ending on or before [date]'s, latest first: the one containing [date], then each earlier
     * one. Hijri months start from the table's last month when [date] is after the table.
     */
    fun periodsBack(date: LocalDate, period: CalendarPeriod): Sequence<DateWindow> {
        val latest = if (period == CalendarPeriod.HIJRI_MONTH) minOf(date, hijri.lastDay) else date
        return generateSequence(periodOf(latest, period)) { periodOf(it.from.minusDays(1), period) }
    }
}

/** Every day from [from] to [to], inclusive; empty when [to] is before [from]. */
internal fun daysBetween(from: LocalDate, to: LocalDate): Sequence<LocalDate> =
    generateSequence(from) { it.plusDays(1) }.takeWhile { !it.isAfter(to) }

private const val DAYS_IN_WEEK = 7L
