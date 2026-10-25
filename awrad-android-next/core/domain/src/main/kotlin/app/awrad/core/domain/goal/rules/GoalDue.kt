package app.awrad.core.domain.goal.rules

import app.awrad.core.domain.goal.GoalDefinition
import app.awrad.core.domain.goal.Schedule
import java.time.LocalDate
import java.time.temporal.ChronoUnit

/**
 * Rule: whether the goal is due on [date] (fixture `goal_is_due`).
 *
 * A day is due when it's inside the active period, not paused, and on the schedule.
 * Every other rule asks this function; none re-derives it.
 */
public fun GoalDefinition.isDueOn(date: LocalDate): Boolean =
    date in activePeriod && paused.none { date in it } && schedule.includes(date, activePeriod.startDate)

private fun Schedule.includes(date: LocalDate, startDate: LocalDate): Boolean = when (this) {
    Schedule.EveryDay, Schedule.OneTime -> true
    is Schedule.Weekdays -> date.dayOfWeek in days
    is Schedule.EveryNDays -> {
        val sinceAnchor = ChronoUnit.DAYS.between(anchorDate ?: startDate, date)
        sinceAnchor >= 0 && sinceAnchor % every == 0L
    }
    is Schedule.MonthDays -> {
        val monthLength = date.lengthOfMonth()
        days.any { minOf(it, monthLength) == date.dayOfMonth }
    }
    is Schedule.SpecificDates -> date in dates
}
