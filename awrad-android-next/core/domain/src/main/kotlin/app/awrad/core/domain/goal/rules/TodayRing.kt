package app.awrad.core.domain.goal.rules

import app.awrad.core.domain.goal.CountEntry
import app.awrad.core.domain.goal.GoalDefinition
import app.awrad.core.domain.goal.GoalTimeline
import app.awrad.core.domain.goal.Requirement
import app.awrad.core.domain.goal.StreakThreshold
import app.awrad.core.domain.hijri.HijriCalendar
import app.awrad.core.domain.hijri.HijriCorrections
import app.awrad.core.domain.practice.WeekStart
import java.time.LocalDate

/** What a list ring fills toward today (decision 33). */
public enum class RingKind {
    /** Today's target (daily goals, N days a period). */
    TARGET,

    /** The week or month so far (period totals). */
    PERIOD_TARGET,

    /** Today's pace share (totals with `daily_pace`). */
    PACE,

    /** The daily streak amount (open-ended totals; trackers with a number, until it's reached). */
    STREAK_AMOUNT,

    /** No ring: not due today, or a tracker without a number or past it. */
    NONE,
}

/** A ring filling [progress] toward [goal]; [goal] is null without a ring, and [progress] is then today's count. */
public data class TodayRing(val kind: RingKind, val progress: Long, val goal: Long?)

/**
 * Rule: what a list ring shows on [date] (fixture `today_ring`). Every ring means today:
 * - daily goals and N days a period: today's target; with sessions, their targets combined, each session counting up
 *   to its own;
 * - period totals: the week or month so far;
 * - totals: their streak amount, which is the pace with `daily_pace`;
 * - trackers: their number until it's reached, and never with any count;
 * - nothing when today isn't due.
 */
public fun GoalTimeline.todayRing(
    date: LocalDate,
    counts: List<CountEntry>,
    weekStart: WeekStart,
    hijriCorrections: HijriCorrections,
): TodayRing {
    val days = GoalDays(this, CountIndex(counts), HijriCalendar(hijriCorrections))
    val goal = days.goalOn(date)
    val today = goal.countOn(date, days.counts)
    val none = TodayRing(RingKind.NONE, today, null)
    val requirement = goal.requirement
    return when {
        requirement is Requirement.PeriodTotal -> days.periodRing(date, weekStart, requirement) ?: none
        !days.isDue(date) -> none
        requirement == Requirement.PerDueDate || requirement is Requirement.DaysPerPeriod ->
            goal.ringOver(listOf(date), days.counts, RingKind.TARGET)
        requirement == Requirement.CumulativeTotal -> {
            val isPace = goal.countPolicy.streakThreshold == StreakThreshold.DailyPace
            val kind = if (isPace) RingKind.PACE else RingKind.STREAK_AMOUNT
            TodayRing(kind, today, days.streakAmount(goal.countPolicy, date))
        }
        goal.countPolicy.streakThreshold == StreakThreshold.AnyCount -> none
        else -> {
            val amount = days.streakAmount(goal.countPolicy, date)
            if (today < amount) TodayRing(RingKind.STREAK_AMOUNT, today, amount) else none
        }
    }
}

/** The week or month so far, or null when [date] is outside the active period or the period has no due days. */
private fun GoalDays.periodRing(
    date: LocalDate,
    weekStart: WeekStart,
    requirement: Requirement.PeriodTotal,
): TodayRing? {
    val goal = goalOn(date)
    val window = PeriodCalendar(weekStart, hijri).periodOf(date, requirement.period)
        ?.takeIf { date in goal.activePeriod }
        ?.let(goal.activePeriod::clip)
        ?.takeIf { it.days().any(::isDue) }
        ?: return null
    return goal.ringOver(window.days().filter { !it.isAfter(date) }.toList(), counts, RingKind.PERIOD_TARGET)
}

/** Progress over [days] toward the target; with sessions, each session counts up to its own target. */
private fun GoalDefinition.ringOver(days: List<LocalDate>, counts: CountIndex, kind: RingKind): TodayRing {
    val progress = progressOver(days, counts)
    return if (sessions.isEmpty()) {
        TodayRing(kind, progress.total, countPolicy.target)
    } else {
        val targets = progress.sessions.map { checkNotNull(it.target) { "A session of a goal with a target has one" } }
        TodayRing(
            kind = kind,
            progress = progress.sessions.zip(targets).sumOf { (session, target) -> minOf(session.progress, target) },
            goal = targets.sum(),
        )
    }
}
