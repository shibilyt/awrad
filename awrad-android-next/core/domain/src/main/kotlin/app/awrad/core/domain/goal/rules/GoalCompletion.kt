package app.awrad.core.domain.goal.rules

import app.awrad.core.domain.goal.CompletionPolicy
import app.awrad.core.domain.goal.CountEntry
import app.awrad.core.domain.goal.GoalDefinition
import app.awrad.core.domain.goal.Requirement
import java.time.LocalDate

/**
 * Rule: whether the goal is completed on [date] (fixture `goal_completion`).
 *
 * - [CompletionPolicy.WHEN_TARGET_REACHED]: a cumulative goal whose total up to [date]
 *   (or its last active day) reaches the target. Other requirements never complete this way.
 * - [CompletionPolicy.WHEN_DURATION_ENDED]: [date] is after the last active day.
 *
 * Clients record completion in the goal document when they first see it (`ended`, reason `completed`), so a completed
 * goal never comes back if an adjustment later lowers its total ([placeGoals]).
 */
public fun GoalDefinition.isCompletedOn(date: LocalDate, counts: List<CountEntry>): Boolean =
    isCompletedOn(date, CountIndex(counts))

internal fun GoalDefinition.isCompletedOn(date: LocalDate, counts: CountIndex): Boolean = when (completion) {
    CompletionPolicy.NEVER -> false
    CompletionPolicy.WHEN_DURATION_ENDED -> activePeriod.lastDay?.let { date.isAfter(it) } ?: false
    CompletionPolicy.WHEN_TARGET_REACHED -> isCumulativeTargetReached(date, counts)
}

private fun GoalDefinition.isCumulativeTargetReached(date: LocalDate, counts: CountIndex): Boolean {
    if (requirement != Requirement.CumulativeTotal || date.isBefore(activePeriod.startDate)) return false
    val days = daysBetween(activePeriod.startDate, date).filter { it in activePeriod }.toList()
    return isMetBy(progressOver(days, counts))
}
