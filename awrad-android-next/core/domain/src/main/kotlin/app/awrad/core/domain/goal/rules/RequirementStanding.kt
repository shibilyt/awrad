package app.awrad.core.domain.goal.rules

import app.awrad.core.domain.goal.CountEntry
import app.awrad.core.domain.goal.DateWindow
import app.awrad.core.domain.goal.GoalDefinition
import app.awrad.core.domain.goal.Requirement
import app.awrad.core.domain.practice.WeekStart
import java.time.LocalDate

public enum class StandingStatus {
    MET,
    NOT_MET,

    /** Outside the active period, on an unscheduled day, or in a window with no due days. */
    NOT_DUE,
}

/** One session's progress against its own target. */
public data class SessionStanding(
    val id: String,
    val progress: Long,
    val target: Long?,
    val isMet: Boolean,
)

/**
 * Where a goal stands on an effective practice day.
 *
 * [progress] counts entries in [window] up to and including the evaluated date. [target] is null for
 * trackers and for goals with sessions; then each of [sessions] reports its own, and [progress] is their sum.
 */
public data class RequirementStanding(
    val status: StandingStatus,
    val window: DateWindow,
    val progress: Long,
    val target: Long?,
    val sessions: List<SessionStanding>,
)

/**
 * Rule: requirement standing on [date] (fixture `requirement_standing`).
 *
 * - Per due date, tracker and days per period: the day itself against the daily target; not due when
 *   [isDueOn] says so. The period view of days per period is [daysPerPeriodOn].
 * - Cumulative total: from the start date to [date].
 * - Period total: the week or month containing [date], clipped to the active period; not due without due days.
 * - Every `not_due` answer has the day as its window and that day's count inside the active period as progress.
 */
public fun GoalDefinition.standingOn(
    date: LocalDate,
    counts: List<CountEntry>,
    weekStart: WeekStart,
): RequirementStanding = standingOn(date, CountIndex(counts), weekStart)

internal fun GoalDefinition.standingOn(date: LocalDate, counts: CountIndex, weekStart: WeekStart): RequirementStanding =
    when (val requirement = requirement) {
        Requirement.PerDueDate, Requirement.Tracker, is Requirement.DaysPerPeriod -> dayStanding(date, counts)
        Requirement.CumulativeTotal -> cumulativeStanding(date, counts)
        is Requirement.PeriodTotal ->
            periodTotalStanding(date, counts, calendarPeriodOf(date, requirement.period, weekStart))
    }

/** The day itself against the daily target (per due date, tracker, and days per period's day view). */
private fun GoalDefinition.dayStanding(date: LocalDate, counts: CountIndex): RequirementStanding =
    if (isDueOn(date)) totals(DateWindow.day(date), date, counts, isDue = true) else notDue(date, counts)

/** Cumulative progress from the start date to [date]; shared with completion. */
internal fun GoalDefinition.cumulativeStanding(date: LocalDate, counts: CountIndex): RequirementStanding =
    if (date in activePeriod) {
        totals(DateWindow(activePeriod.startDate, date), date, counts, isDue = true)
    } else {
        notDue(date, counts)
    }

/** A week or month with no due days (outside the active period, fully paused) isn't due. */
private fun GoalDefinition.periodTotalStanding(
    date: LocalDate,
    counts: CountIndex,
    calendarPeriod: DateWindow,
): RequirementStanding {
    val window = activePeriod.clip(calendarPeriod)?.takeIf { date in activePeriod }
    return if (window != null && window.days().any { isDueOn(it) }) {
        totals(window, date, counts, isDue = true)
    } else {
        notDue(date, counts)
    }
}

/** Every `not_due` answer: the day as its window, and that day's count inside the active period (0 outside it). */
private fun GoalDefinition.notDue(date: LocalDate, counts: CountIndex): RequirementStanding =
    totals(DateWindow.day(date), date, if (date in activePeriod) counts else CountIndex.EMPTY, isDue = false)

/** With sessions, only counts for a session are progress: untagged counts are ignored, total included. */
private fun GoalDefinition.totals(
    window: DateWindow,
    upTo: LocalDate,
    counts: CountIndex,
    isDue: Boolean,
): RequirementStanding {
    val isTracker = requirement == Requirement.Tracker
    val sessionStandings = sessions.map { session ->
        val sessionProgress = counts.sessionTotal(window, upTo, session.id)
        SessionStanding(
            id = session.id,
            progress = sessionProgress,
            target = session.countPolicy.target,
            isMet = session.countPolicy.meetsTarget(sessionProgress),
        )
    }
    val progress = if (sessions.isEmpty()) counts.total(window, upTo) else sessionStandings.sumOf { it.progress }
    val isMet = when {
        sessions.isNotEmpty() -> sessionStandings.all { it.isMet }
        isTracker -> progress > 0
        else -> countPolicy.meetsTarget(progress)
    }
    return RequirementStanding(
        status = when {
            !isDue -> StandingStatus.NOT_DUE
            isMet -> StandingStatus.MET
            else -> StandingStatus.NOT_MET
        },
        window = window,
        progress = progress,
        target = if (isTracker || sessions.isNotEmpty()) null else countPolicy.target,
        sessions = sessionStandings,
    )
}
