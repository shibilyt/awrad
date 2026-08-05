package app.awrad.awrad_dhikrgoalstracker.notification

import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import java.time.LocalDate
import java.math.BigInteger

data class ObligationScope(
    val effectiveDate: LocalDate,
    val identifier: String = effectiveDate.toString(),
)

data class ObligationWindow(
    val scope: ObligationScope,
    val deadlineMillis: Long?,
    val startMillis: Long? = null,
)

data class ResolvedObligationInterval(
    val startMillis: Long?,
    val endMillis: Long?,
)

data class ResolvedObligationSlot(
    val slotId: AwradId,
    val slotType: GoalSlotType,
    val interval: ResolvedObligationInterval? = null,
)

data class NotificationObligation(
    val goal: Goal,
    val window: ObligationWindow,
    val isScheduled: Boolean,
    val resolvedSlots: List<ResolvedObligationSlot>,
    val progress: ObligationProgress,
    val currentStreak: Int,
    val urgencyEnabled: Boolean,
    val planningNowMillis: Long,
)

enum class NudgeKind {
    DEADLINE_WARNING,
    STREAK_GUARDIAN,
}

data class NudgeCandidateKey(
    val goalId: AwradId,
    val obligationScope: String,
    val slotId: AwradId?,
    val kind: NudgeKind,
)

data class NudgeCandidate(
    val key: NudgeCandidateKey,
    val triggerAtMillis: Long,
    val expiresAtMillis: Long,
    val progressCount: Long,
    val remainingCount: Long?,
    val currentStreak: Int = 0,
) {
    init {
        require(triggerAtMillis < expiresAtMillis) { "Nudge trigger must precede its expiry" }
    }
}

class NotificationObligationPlanner {
    fun plan(obligation: NotificationObligation): List<NudgeCandidate> {
        if (!obligation.urgencyEnabled || !obligation.isScheduled || obligation.isBlocked()) {
            return emptyList()
        }

        return buildList {
            addAll(deadlineWarnings(obligation))
            streakGuardian(obligation)?.let(::add)
        }.sortedWith(
            compareBy<NudgeCandidate>(
                { it.triggerAtMillis },
                { it.key.goalId.toString() },
                { it.key.obligationScope },
                { it.key.slotId?.toString().orEmpty() },
                { it.key.kind.ordinal },
            ),
        )
    }

    private fun deadlineWarnings(obligation: NotificationObligation): List<NudgeCandidate> {
        return when (obligation.goal.targetPolicy) {
            TargetPolicy.PER_DUE_DATE -> perDueDateWarnings(obligation)
            TargetPolicy.CUMULATIVE_TOTAL -> cumulativeDeadlineWarning(obligation).orEmpty()
            TargetPolicy.PERIOD_TOTAL, TargetPolicy.NONE -> emptyList()
        }
    }

    private fun perDueDateWarnings(obligation: NotificationObligation): List<NudgeCandidate> {
        return candidatesForDeadlineWarning(obligation).mapNotNull { (slot, count, threshold) ->
            if (count >= threshold) return@mapNotNull null
            val warningAt = when (slot?.slotType) {
                null, GoalSlotType.ANYTIME -> obligation.window.deadlineMillis?.let(::dueDateWarningAt)
                GoalSlotType.TIME_WINDOW, GoalSlotType.PRAYER -> slot.interval?.proportionalWarningAt()
            } ?: return@mapNotNull null
            val expiry = when (slot?.slotType) {
                null, GoalSlotType.ANYTIME -> obligation.window.deadlineMillis
                GoalSlotType.TIME_WINDOW, GoalSlotType.PRAYER -> slot.interval?.endMillis
            } ?: return@mapNotNull null
            if (warningAt <= obligation.planningNowMillis) return@mapNotNull null

            NudgeCandidate(
                key = NudgeCandidateKey(
                    goalId = obligation.goal.id,
                    obligationScope = obligation.window.scope.identifier,
                    slotId = slot?.slotId,
                    kind = NudgeKind.DEADLINE_WARNING,
                ),
                triggerAtMillis = warningAt,
                expiresAtMillis = expiry,
                progressCount = count,
                remainingCount = threshold - count,
                currentStreak = obligation.currentStreak,
            )
        }
    }

    private fun cumulativeDeadlineWarning(obligation: NotificationObligation): List<NudgeCandidate>? {
        if (!obligation.goal.hasExplicitCumulativeDeadline()) return null
        val threshold = ThresholdResolver.resolve(
            obligation.goal.reminderThreshold,
            ThresholdValues(
                obligation.goal.minimumStreakCount,
                obligation.goal.targetCount,
                obligation.goal.maximumCount,
            ),
        )?.toLong() ?: return null
        val progress = obligation.progress.lifetimeCount
        if (progress >= threshold) return null

        val warningAt = proportionalWarningAt(
            obligation.window.startMillis,
            obligation.window.deadlineMillis,
        ) ?: return null
        if (warningAt <= obligation.planningNowMillis) return null

        return listOf(
            NudgeCandidate(
                key = NudgeCandidateKey(
                    goalId = obligation.goal.id,
                    obligationScope = obligation.window.scope.identifier,
                    slotId = null,
                    kind = NudgeKind.DEADLINE_WARNING,
                ),
                triggerAtMillis = warningAt,
                expiresAtMillis = obligation.window.deadlineMillis ?: return null,
                progressCount = progress,
                remainingCount = threshold - progress,
                currentStreak = obligation.currentStreak,
            ),
        )
    }

    private fun candidatesForDeadlineWarning(
        obligation: NotificationObligation,
    ): List<Triple<ResolvedObligationSlot?, Long, Long>> {
        val activeSlotsById = obligation.goal.activeSlots.associateBy { it.id }
        val resolvedActiveSlots = obligation.resolvedSlots.filter { resolved ->
            activeSlotsById[resolved.slotId]?.slotType == resolved.slotType
        }
        if (resolvedActiveSlots.isEmpty() && obligation.goal.activeSlots.isEmpty()) {
            val threshold = ThresholdResolver.resolve(
                obligation.goal.reminderThreshold,
                ThresholdValues(
                    obligation.goal.minimumStreakCount,
                    obligation.goal.targetCount,
                    obligation.goal.maximumCount,
                ),
            )?.toLong() ?: return emptyList()
            return listOf(Triple(null, obligation.progress.occurrenceCount, threshold))
        }

        return resolvedActiveSlots.mapNotNull { resolved ->
            val slot = activeSlotsById.getValue(resolved.slotId)
            val threshold = ThresholdResolver.resolve(
                slot.reminderThreshold,
                ThresholdValues(slot.minimumCount, slot.targetCount, slot.maximumCount),
            )?.toLong() ?: return@mapNotNull null
            Triple(resolved, obligation.progress.slotCounts[slot.id] ?: 0L, threshold)
        }
    }

    private fun streakGuardian(obligation: NotificationObligation): NudgeCandidate? {
        if (obligation.currentStreak < MINIMUM_GUARDED_STREAK ||
            obligation.goal.targetPolicy == TargetPolicy.CUMULATIVE_TOTAL ||
            obligation.continuitySatisfied()
        ) {
            return null
        }
        val deadline = obligation.window.deadlineMillis ?: return null
        val triggerAt = subtractExactlyOrNull(deadline, STREAK_GUARDIAN_LEAD_MILLIS) ?: return null
        if (triggerAt <= obligation.planningNowMillis) return null

        val progressCount = when (obligation.goal.targetPolicy) {
            TargetPolicy.PER_DUE_DATE, TargetPolicy.NONE -> obligation.progress.occurrenceCount
            TargetPolicy.PERIOD_TOTAL -> obligation.progress.periodCount
            TargetPolicy.CUMULATIVE_TOTAL -> return null
        }
        return NudgeCandidate(
            key = NudgeCandidateKey(
                goalId = obligation.goal.id,
                obligationScope = obligation.window.scope.identifier,
                slotId = null,
                kind = NudgeKind.STREAK_GUARDIAN,
            ),
            triggerAtMillis = triggerAt,
            expiresAtMillis = deadline,
            progressCount = progressCount,
            remainingCount = obligation.remainingForStreak(progressCount),
            currentStreak = obligation.currentStreak,
        )
    }

    private fun NotificationObligation.isBlocked(): Boolean =
        !goal.isActive ||
            goal.isCompleted ||
            ObligationSemantics.isGoalExpired(goal, window.scope.effectiveDate) ||
            window.deadlineMillis?.let { planningNowMillis >= it } == true

    private fun NotificationObligation.continuitySatisfied(): Boolean = when (goal.targetPolicy) {
        TargetPolicy.NONE ->
            if (goal.activeSlots.isNotEmpty()) {
                ObligationSemantics.isOccurrenceContinuous(goal, progress.slotCounts)
            } else {
                ThresholdResolver.resolve(
                    goal.streakThreshold,
                    ThresholdValues(goal.minimumStreakCount, goal.targetCount, goal.maximumCount),
                )?.let { progress.occurrenceCount >= it } ?: false
            }
        TargetPolicy.PER_DUE_DATE ->
            if (goal.activeSlots.isNotEmpty()) {
                ObligationSemantics.isOccurrenceContinuous(goal, progress.slotCounts)
            } else {
                ObligationSemantics.isObligationSatisfied(
                    goal,
                    window.scope.effectiveDate,
                    progress,
                    ObligationThreshold.STREAK,
                )
            }
        TargetPolicy.PERIOD_TOTAL -> ObligationSemantics.isObligationSatisfied(
            goal,
            window.scope.effectiveDate,
            progress,
            ObligationThreshold.STREAK,
        )
        TargetPolicy.CUMULATIVE_TOTAL -> false
    }

    private fun NotificationObligation.remainingForStreak(progressCount: Long): Long? {
        if (goal.targetPolicy == TargetPolicy.NONE) return null
        val threshold = ThresholdResolver.resolve(
            goal.streakThreshold,
            ThresholdValues(goal.minimumStreakCount, goal.targetCount, goal.maximumCount),
        )?.toLong() ?: return null
        return (threshold - progressCount).coerceAtLeast(0)
    }

    private fun ResolvedObligationInterval.proportionalWarningAt(): Long? =
        proportionalWarningAt(startMillis, endMillis)

    private fun proportionalWarningAt(start: Long?, end: Long?): Long? {
        start ?: return null
        end ?: return null
        if (end <= start) return null
        // BigInteger preserves the 4/5 interval calculation even across the full Long epoch range.
        val duration = BigInteger.valueOf(end).subtract(BigInteger.valueOf(start))
        val offset = duration.multiply(FOUR).divide(FIVE)
        return BigInteger.valueOf(start).add(offset).longValueExact()
    }

    private fun Goal.hasExplicitCumulativeDeadline(): Boolean =
        endDate != null || (durationDays ?: 0) > 0

    private fun dueDateWarningAt(deadlineMillis: Long): Long? =
        subtractExactlyOrNull(deadlineMillis, DUE_DATE_WARNING_LEAD_MILLIS)

    private fun subtractExactlyOrNull(value: Long, amount: Long): Long? =
        runCatching { Math.subtractExact(value, amount) }.getOrNull()

    private companion object {
        const val MINIMUM_GUARDED_STREAK = 3
        const val DUE_DATE_WARNING_LEAD_MILLIS = 150L * 60_000L
        const val STREAK_GUARDIAN_LEAD_MILLIS = 30L * 60_000L
        val FOUR: BigInteger = BigInteger.valueOf(4L)
        val FIVE: BigInteger = BigInteger.valueOf(5L)
    }
}
