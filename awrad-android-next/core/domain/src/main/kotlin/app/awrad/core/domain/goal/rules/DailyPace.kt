package app.awrad.core.domain.goal.rules

import app.awrad.core.domain.goal.CountEntry
import app.awrad.core.domain.goal.GoalTimeline
import app.awrad.core.domain.hijri.HijriCalendar
import app.awrad.core.domain.hijri.HijriCorrections
import java.time.LocalDate

/**
 * Today's share of a total goal with an end (decision 28): [pace] is what's left before today ([remaining]) divided by
 * the due days from today to the last day ([dueDaysLeft]), rounded up. All null for goals other than totals without
 * sessions; [pace] and [dueDaysLeft] null without an end, and [pace] null when today isn't due.
 */
public data class DailyPace(val pace: Long?, val remaining: Long?, val dueDaysLeft: Int?) {
    internal companion object {
        val NONE = DailyPace(pace = null, remaining = null, dueDaysLeft = null)
    }
}

/**
 * Rule: the daily pace on [date] (fixture `daily_pace`). It excludes [date]'s own counts, so it's fixed for the day and
 * recalculated the next. Each day is judged against the end its version had then, even after the goal ended early.
 */
public fun GoalTimeline.dailyPaceOn(
    date: LocalDate,
    counts: List<CountEntry>,
    hijriCorrections: HijriCorrections,
): DailyPace = GoalDays(this, CountIndex(counts), HijriCalendar(hijriCorrections)).paceOn(date)
