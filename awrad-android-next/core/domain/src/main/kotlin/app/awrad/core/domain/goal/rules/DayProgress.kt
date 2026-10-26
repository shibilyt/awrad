package app.awrad.core.domain.goal.rules

import app.awrad.core.domain.goal.CalendarPeriod
import app.awrad.core.domain.goal.CountEntry
import app.awrad.core.domain.goal.CountPolicy
import app.awrad.core.domain.goal.DateWindow
import app.awrad.core.domain.goal.GoalDefinition
import app.awrad.core.domain.hijri.HijriCalendar
import app.awrad.core.domain.practice.WeekStart
import java.time.LocalDate
import java.time.temporal.TemporalAdjusters

/** Count entries indexed by day, so rules that walk many days look each one up once. */
internal class CountIndex(entries: List<CountEntry>) {
    private val byDate: Map<LocalDate, List<CountEntry>> = entries.groupBy { it.date }

    /** The goal's total on [date]: every entry, whichever session it belongs to. */
    fun total(date: LocalDate): Long = byDate[date].orEmpty().sumOf { it.count }

    fun sessionTotal(date: LocalDate, sessionId: String): Long =
        byDate[date].orEmpty().filter { it.sessionId == sessionId }.sumOf { it.count }

    /** The total of entries in [window] up to and including [upTo]. Later entries aren't counted yet. */
    fun total(window: DateWindow, upTo: LocalDate): Long = counted(window, upTo).sumOf(::total)

    fun sessionTotal(window: DateWindow, upTo: LocalDate, sessionId: String): Long =
        counted(window, upTo).sumOf { sessionTotal(it, sessionId) }

    private fun counted(window: DateWindow, upTo: LocalDate): Sequence<LocalDate> =
        byDate.keys.asSequence().filter { it in window && !it.isAfter(upTo) }

    companion object {
        val EMPTY = CountIndex(emptyList())
    }
}

/** Which value of a count policy a single day is measured against. */
internal enum class DayMeasure {
    TARGET,
    STREAK_THRESHOLD,
}

internal fun CountPolicy.isMetBy(count: Long, measure: DayMeasure): Boolean = when (measure) {
    DayMeasure.TARGET -> meetsTarget(count)
    DayMeasure.STREAK_THRESHOLD -> meetsStreakThreshold(count)
}

/**
 * Whether one day's counts meet [measure]. Without sessions the goal's count policy applies;
 * with sessions, each session must meet its own.
 */
internal fun GoalDefinition.dayMeets(date: LocalDate, counts: CountIndex, measure: DayMeasure): Boolean =
    if (sessions.isEmpty()) {
        countPolicy.isMetBy(counts.total(date), measure)
    } else {
        sessions.all { it.countPolicy.isMetBy(counts.sessionTotal(date, it.id), measure) }
    }

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

private const val DAYS_IN_WEEK = 7L
