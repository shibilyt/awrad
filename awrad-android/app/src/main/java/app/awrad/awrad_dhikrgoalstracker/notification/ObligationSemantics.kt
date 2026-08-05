package app.awrad.awrad_dhikrgoalstracker.notification

import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import app.awrad.awrad_dhikrgoalstracker.data.model.Threshold
import app.awrad.awrad_dhikrgoalstracker.util.EffectiveDayWindow
import app.awrad.awrad_dhikrgoalstracker.util.GoalProgressCalculator
import java.time.Instant
import java.time.LocalDate
import java.time.temporal.ChronoUnit

data class ThresholdValues(
    val minimum: Int?,
    val target: Int?,
    val maximum: Int?,
)

object ThresholdResolver {
    fun resolve(threshold: Threshold, values: ThresholdValues): Int? =
        when (threshold) {
            Threshold.AnyPositive -> 1
            Threshold.Minimum -> values.minimum
            Threshold.Target -> values.target
            Threshold.Maximum -> values.maximum
            is Threshold.Custom -> threshold.count
        }?.takeIf { it > 0 }
}

enum class ContinuityUnit {
    SCHEDULED_OCCURRENCE,
    COMPLETED_PERIOD,
    NONE,
}

data class ObligationLifecycle(
    val obligationSatisfied: Boolean,
    val windowClosed: Boolean,
    val goalExpired: Boolean,
    val goalCompleted: Boolean,
)

enum class ObligationThreshold {
    REMINDER,
    STREAK,
    COMPLETION,
}

data class ObligationProgress(
    val occurrenceCount: Long = 0,
    val periodCount: Long = 0,
    val lifetimeCount: Long = 0,
    val slotCounts: Map<AwradId, Long> = emptyMap(),
)

object ObligationSemantics {
    fun continuityUnit(targetPolicy: TargetPolicy): ContinuityUnit = when (targetPolicy) {
        TargetPolicy.PER_DUE_DATE, TargetPolicy.NONE -> ContinuityUnit.SCHEDULED_OCCURRENCE
        TargetPolicy.PERIOD_TOTAL -> ContinuityUnit.COMPLETED_PERIOD
        TargetPolicy.CUMULATIVE_TOTAL -> ContinuityUnit.NONE
    }

    fun lifecycle(
        goal: Goal,
        now: Instant,
        window: EffectiveDayWindow?,
        satisfied: Boolean,
    ): ObligationLifecycle = ObligationLifecycle(
        obligationSatisfied = satisfied,
        windowClosed = window?.let { now >= it.endExclusive } ?: false,
        goalExpired = isGoalExpired(goal, window?.effectiveDate ?: now.atZone(java.time.ZoneOffset.UTC).toLocalDate()),
        goalCompleted = goal.completedAt != null,
    )

    fun isGoalExpired(goal: Goal, date: LocalDate): Boolean {
        if (goal.endDate?.let { date.isAfter(it) } == true) return true
        val duration = goal.durationDays?.takeIf { it > 0 } ?: return false
        return ChronoUnit.DAYS.between(goal.startDate, date) >= duration
    }

    fun isObligationSatisfied(
        goal: Goal,
        occurrenceDate: LocalDate,
        progress: ObligationProgress,
        threshold: ObligationThreshold,
    ): Boolean {
        if (goal.targetPolicy == TargetPolicy.NONE) return progress.occurrenceCount > 0
        val resolvedThreshold = ThresholdResolver.resolve(
            goal.thresholdFor(threshold),
            ThresholdValues(goal.minimumStreakCount, goal.targetCount, goal.maximumCount),
        ) ?: return false
        return when (goal.targetPolicy) {
            TargetPolicy.PER_DUE_DATE -> progress.occurrenceCount >= resolvedThreshold
            TargetPolicy.PERIOD_TOTAL ->
                GoalProgressCalculator.currentProgressWindow(goal, occurrenceDate) != null &&
                    progress.periodCount >= resolvedThreshold
            TargetPolicy.CUMULATIVE_TOTAL -> progress.lifetimeCount >= resolvedThreshold
            TargetPolicy.NONE -> error("Handled above")
        }
    }

    /**
     * Each configured active slot owns its own threshold; aggregate progress cannot substitute
     * for a missing slot during occurrence continuity.
     */
    fun isOccurrenceContinuous(
        goal: Goal,
        slotCounts: Map<AwradId, Long>,
        threshold: ObligationThreshold = ObligationThreshold.STREAK,
    ): Boolean {
        val activeSlots = goal.activeSlots
        if (activeSlots.isEmpty()) return false
        return activeSlots.all { slot ->
            val resolvedThreshold = ThresholdResolver.resolve(
                slot.thresholdFor(threshold),
                ThresholdValues(slot.minimumCount, slot.targetCount, slot.maximumCount),
            ) ?: return false
            (slotCounts[slot.id] ?: 0L) >= resolvedThreshold
        }
    }

    private fun Goal.thresholdFor(threshold: ObligationThreshold): Threshold = when (threshold) {
        ObligationThreshold.REMINDER -> reminderThreshold
        ObligationThreshold.STREAK -> streakThreshold
        ObligationThreshold.COMPLETION -> completionThreshold
    }

    private fun app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot.thresholdFor(
        threshold: ObligationThreshold,
    ): Threshold = when (threshold) {
        ObligationThreshold.REMINDER -> reminderThreshold
        ObligationThreshold.STREAK -> streakThreshold
        ObligationThreshold.COMPLETION -> completionThreshold
    }
}
