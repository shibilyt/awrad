package app.awrad.core.domain.goal.rules

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.goal.CountEntry
import app.awrad.core.domain.goal.CountLogEntry
import app.awrad.core.domain.goal.GoalCounts
import app.awrad.core.domain.goal.GoalDocument
import app.awrad.core.domain.goal.GoalTimeline

/**
 * Rule: a goal's counts from the count log (fixture `count_attribution`; decisions 1 and 2), summed per day and
 * session, by day then session (no session first).
 *
 * - A [GoalCounts.SHARED] goal takes every entry of [dhikrId] without a goal ID; a [GoalCounts.DEDICATED] one only
 *   entries with its own [goalId].
 * - With sessions in that day's version, an entry goes to its session, and one without a session, or with a session the
 *   goal doesn't have, is dropped; without sessions it goes to the day.
 * - A sum of 0 or less is no count. Dates aren't filtered: the rules ignore counts outside the active period.
 */
public fun attributedCounts(
    goalId: AwradId,
    dhikrId: AwradId,
    counts: GoalCounts,
    timeline: GoalTimeline,
    log: List<CountLogEntry>,
): List<CountEntry> = log
    .asSequence()
    .filter { it.dhikrId == dhikrId }
    .filter { if (counts == GoalCounts.DEDICATED) it.goalId == goalId else it.goalId == null }
    .mapNotNull { entry ->
        val sessions = timeline.goalOn(entry.practiceDay, capEnded = false).sessions
        when {
            sessions.isEmpty() -> (entry.practiceDay to null) to entry.amount
            sessions.any { it.id == entry.sessionId } -> (entry.practiceDay to entry.sessionId) to entry.amount
            else -> null
        }
    }
    .groupingBy { it.first }
    .fold(0L) { sum, (_, amount) -> sum + amount }
    .filterValues { it > 0 }
    .map { (key, count) -> CountEntry(date = key.first, sessionId = key.second, count = count) }
    .sortedWith(compareBy<CountEntry> { it.date }.thenBy { it.sessionId.orEmpty() })

/** [attributedCounts] for a goal document stored under [goalId]. */
public fun GoalDocument.countsFrom(goalId: AwradId, log: List<CountLogEntry>): List<CountEntry> =
    attributedCounts(goalId, dhikrId, counts, timeline, log)
