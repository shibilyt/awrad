package app.awrad.core.domain.goal.rules

import app.awrad.core.domain.goal.CompletionPolicy
import app.awrad.core.domain.goal.CountEntry
import app.awrad.core.domain.goal.GoalDefinition
import app.awrad.core.domain.goal.Requirement
import java.time.LocalDate

/**
 * Rule: whether the goal is completed on [date] (fixture `goal_completion`).
 *
 * Completion is derived, never stored by counting code, so a goal whose counts drop back below
 * the target is no longer completed.
 * - [CompletionPolicy.WHEN_TARGET_REACHED]: a cumulative goal whose total up to [date]
 *   (or its last active day) reaches the target. Other requirements never complete this way.
 * - [CompletionPolicy.WHEN_DURATION_ENDED]: [date] is after the last active day.
 */
public fun GoalDefinition.isCompletedOn(date: LocalDate, counts: List<CountEntry>): Boolean = when (completion) {
    CompletionPolicy.NEVER -> false
    CompletionPolicy.WHEN_DURATION_ENDED -> activePeriod.lastDay?.let { date.isAfter(it) } ?: false
    CompletionPolicy.WHEN_TARGET_REACHED -> isCumulativeTargetReached(date, CountIndex(counts))
}

private fun GoalDefinition.isCumulativeTargetReached(date: LocalDate, counts: CountIndex): Boolean {
    if (requirement != Requirement.CumulativeTotal || date.isBefore(activePeriod.startDate)) return false
    val evaluated = activePeriod.lastDay?.let { minOf(date, it) } ?: date
    return cumulativeStanding(evaluated, counts).status == StandingStatus.MET
}
