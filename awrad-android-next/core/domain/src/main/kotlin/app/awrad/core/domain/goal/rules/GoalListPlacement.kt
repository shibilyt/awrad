package app.awrad.core.domain.goal.rules

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.goal.CompletionPolicy
import app.awrad.core.domain.goal.CountEntry
import app.awrad.core.domain.goal.EndReason
import app.awrad.core.domain.goal.GoalOrder
import app.awrad.core.domain.goal.GoalTimeline
import app.awrad.core.domain.goal.Requirement
import app.awrad.core.domain.hijri.HijriCalendar
import app.awrad.core.domain.hijri.HijriCorrections
import java.time.LocalDate

/** A goal to place in My Goals: its ID, its timeline and its attributed counts. */
public data class PlacementGoal(val id: AwradId, val timeline: GoalTimeline, val counts: List<CountEntry>)

/** A goal in Upcoming, with its next due day (null when none is due in the next 400 days). */
public data class UpcomingGoal(val id: AwradId, val nextDue: LocalDate?)

/** How a goal in History finished. */
public enum class Finish {
    COMPLETED,
    ENDED,
}

/** A goal in History: how it finished, and on which day (its last). */
public data class FinishedGoal(val id: AwradId, val finish: Finish, val on: LocalDate)

/** My Goals' sections (decisions 12, 25, 26, 30 and 46), each in its order. */
public data class GoalLists(
    val today: List<AwradId>,
    val upcoming: List<UpcomingGoal>,
    val tracking: List<AwradId>,
    val paused: List<AwradId>,
    val history: List<FinishedGoal>,
)

/**
 * Rule: where each goal shows on [today] (fixture `goal_list_placement`). The first match wins:
 * 1. History: ended in the document, completed by its policy, past its last day, or no scheduled day in the next
 *    400 days;
 * 2. Paused: paused today;
 * 3. Tracking: trackers;
 * 4. Today: due today, or with a day pending make-up;
 * 5. Upcoming, with its next due day.
 *
 * Today, Tracking and Paused follow [order], then the goals it doesn't name by creation day and ID; Upcoming is
 * soonest first, then that order; History newest first, then that order.
 *
 * A goal found completed or past its end here should be recorded as ended in its document (README.md, "Ending").
 */
public fun placeGoals(
    goals: List<PlacementGoal>,
    order: GoalOrder,
    today: LocalDate,
    hijriCorrections: HijriCorrections,
): GoalLists {
    val hijri = HijriCalendar(hijriCorrections)
    val position = order.goalIds.withIndex().associate { (index, id) -> id to index }
    val byOrder = compareBy<PlacementGoal> { position[it.id] ?: Int.MAX_VALUE }
        .thenBy { it.timeline.createdOn }
        .thenBy { it.id.value }
    val placed = goals.map { goal ->
        goal to GoalDays(goal.timeline, CountIndex(goal.counts), hijri).placementOn(today)
    }
    fun ids(section: Placement) =
        placed.filter { it.second == section }.map { it.first }.sortedWith(byOrder).map { it.id }
    val upcoming = placed.placedIn<Placement.Upcoming>().sortedWith(
        compareBy<Pair<PlacementGoal, Placement.Upcoming>, LocalDate?>(nullsLast()) { it.second.nextDue }
            .thenBy(byOrder) { it.first },
    )
    val history = placed.placedIn<Placement.History>().sortedWith(
        compareByDescending<Pair<PlacementGoal, Placement.History>> { it.second.on }.thenBy(byOrder) { it.first },
    )
    return GoalLists(
        today = ids(Placement.Today),
        upcoming = upcoming.map { (goal, placement) -> UpcomingGoal(goal.id, placement.nextDue) },
        tracking = ids(Placement.Tracking),
        paused = ids(Placement.Paused),
        history = history.map { (goal, placement) -> FinishedGoal(goal.id, placement.finish, placement.on) },
    )
}

private inline fun <reified P : Placement> List<Pair<PlacementGoal, Placement>>.placedIn() =
    mapNotNull { (goal, placement) -> (placement as? P)?.let { goal to it } }

private sealed interface Placement {
    data class History(val finish: Finish, val on: LocalDate) : Placement

    data object Paused : Placement

    data object Tracking : Placement

    data object Today : Placement

    data class Upcoming(val nextDue: LocalDate?) : Placement
}

private fun GoalDays.placementOn(today: LocalDate): Placement {
    val goal = goalOn(today)
    return finishOn(today) ?: when {
        goal.isPausedOn(today) -> Placement.Paused
        goal.requirement == Requirement.Tracker -> Placement.Tracking
        isDue(today) || statusesOn(today).values.any { it.status == DayStatus.PENDING } -> Placement.Today
        else -> Placement.Upcoming(nextDue = horizon(today).firstOrNull(::isDue))
    }
}

/** How and when the goal finished, or null while it's still running. */
private fun GoalDays.finishOn(today: LocalDate): Placement.History? {
    timeline.ended?.let { ended ->
        val finish = if (ended.reason == EndReason.COMPLETED) Finish.COMPLETED else Finish.ENDED
        return Placement.History(finish, ended.on)
    }
    val goal = goalOn(today)
    val last = goal.activePeriod.lastDay
    return when {
        goal.isCompletedOn(today, counts) -> Placement.History(
            Finish.COMPLETED,
            if (goal.completion == CompletionPolicy.WHEN_DURATION_ENDED) {
                checkNotNull(last)
            } else {
                daysBetween(startDate, today).first { goal.isCompletedOn(it, counts) }
            },
        )
        last != null && today.isAfter(last) -> Placement.History(Finish.ENDED, last)
        horizon(today, from = today).any(::isScheduled) -> null
        else -> Placement.History(
            Finish.ENDED,
            daysBetween(startDate, today.minusDays(1)).lastOrNull(::isScheduled) ?: startDate,
        )
    }
}

/** The days ahead within the 400-day horizon and the goal's last day: from tomorrow, or from [from]. */
private fun GoalDays.horizon(today: LocalDate, from: LocalDate = today.plusDays(1)): Sequence<LocalDate> {
    val end = today.plusDays(HORIZON_DAYS)
    return daysBetween(from, lastDay(today)?.let { minOf(it, end) } ?: end)
}
