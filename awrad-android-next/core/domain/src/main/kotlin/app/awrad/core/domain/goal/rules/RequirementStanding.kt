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
 * trackers and for goals with sessions; then each of [sessions] reports its own. For days-per-period
 * goals, [progress] is the qualifying days and [target] the required days (see [daysPerPeriodOn]).
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
 * - Per due date and tracker: the day itself; not due when [isDueOn] says so.
 * - Cumulative total: from the start date to [date].
 * - Period total: the week or month containing [date], clipped to the active period.
 * - Days per period: delegates to [daysPerPeriodOn].
 */
public fun GoalDefinition.standingOn(
    date: LocalDate,
    counts: List<CountEntry>,
    weekStart: WeekStart,
): RequirementStanding = standingOn(date, CountIndex(counts), weekStart)

internal fun GoalDefinition.standingOn(date: LocalDate, counts: CountIndex, weekStart: WeekStart): RequirementStanding =
    when (val requirement = requirement) {
        Requirement.PerDueDate -> totals(DateWindow.day(date), date, counts, isDue = isDueOn(date))
        Requirement.Tracker -> totals(DateWindow.day(date), date, counts, isDue = isDueOn(date), isTracker = true)
        Requirement.CumulativeTotal -> cumulativeStanding(date, counts)
        is Requirement.PeriodTotal ->
            periodTotalStanding(date, counts, calendarPeriodOf(date, requirement.period, weekStart))
        is Requirement.DaysPerPeriod -> daysPerPeriodOn(date, counts, weekStart).asRequirementStanding()
    }

/** Cumulative progress from the start date to [date]; shared with completion. */
internal fun GoalDefinition.cumulativeStanding(date: LocalDate, counts: CountIndex): RequirementStanding =
    if (date in activePeriod) {
        totals(DateWindow(activePeriod.startDate, date), date, counts, isDue = true)
    } else {
        totals(DateWindow.day(date), date, counts, isDue = false)
    }

private fun GoalDefinition.periodTotalStanding(
    date: LocalDate,
    counts: CountIndex,
    calendarPeriod: DateWindow,
): RequirementStanding {
    val window = activePeriod.clip(calendarPeriod)?.takeIf { date in activePeriod }
        ?: return totals(DateWindow.day(date), date, counts, isDue = false)
    return totals(window, date, counts, isDue = window.days().any { isDueOn(it) })
}

private fun GoalDefinition.totals(
    window: DateWindow,
    upTo: LocalDate,
    counts: CountIndex,
    isDue: Boolean,
    isTracker: Boolean = false,
): RequirementStanding {
    val progress = counts.total(window, upTo)
    val sessionStandings = sessions.map { session ->
        val sessionProgress = counts.sessionTotal(window, upTo, session.id)
        SessionStanding(
            id = session.id,
            progress = sessionProgress,
            target = session.countPolicy.target,
            isMet = session.countPolicy.meetsTarget(sessionProgress),
        )
    }
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
