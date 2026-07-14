package app.awrad.awrad_dhikrgoalstracker.util

import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType

/**
 * Answers whether at least one counting context on a goal can accept another count.
 *
 * The current-count selection mirrors GoalRepositoryImpl's cap window: a single anytime
 * slot uses the goal progress window, while multi-slot and timed/prayer slots use the
 * current occurrence's slot count.
 */
object GoalCountingEligibility {

    fun canContinueCounting(
        goal: Goal,
        progressCount: Long,
        slotCounts: Map<AwradId, Long>,
    ): Boolean {
        val slots = goal.activeSlots
        if (slots.isEmpty()) {
            return CountCapCalculator.canApplyIncrement(
                currentCount = progressCount,
                targetCount = GoalProgressCalculator.getTargetCount(goal).takeIf { it > 0 },
                maximumCount = goal.maximumCount,
                capBehavior = goal.capBehavior,
            )
        }

        return slots.any { slot ->
            val currentCount = if (slots.size == 1 && slot.slotType == GoalSlotType.ANYTIME) {
                progressCount
            } else {
                slotCounts[slot.id] ?: 0L
            }
            canIncrementSlot(goal, slot, currentCount)
        }
    }

    private fun canIncrementSlot(goal: Goal, slot: GoalSlot, currentCount: Long): Boolean =
        CountCapCalculator.canApplyIncrement(
            currentCount = currentCount,
            targetCount = slot.targetCount
                ?: GoalProgressCalculator.getTargetCount(goal).takeIf { it > 0 },
            maximumCount = slot.maximumCount ?: goal.maximumCount,
            capBehavior = slot.capBehavior,
        )
}
