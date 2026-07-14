package app.awrad.awrad_dhikrgoalstracker.domain.usecase

import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.repository.GoalRepository
import javax.inject.Inject

sealed interface AllowCountingPastTargetResult {
    data class Updated(val goal: Goal) : AllowCountingPastTargetResult
    data object GoalNotFound : AllowCountingPastTargetResult
    data object NotBlockedAtTarget : AllowCountingPastTargetResult
}

class AllowCountingPastTargetUseCase @Inject constructor(
    private val goalRepository: GoalRepository,
) {
    suspend operator fun invoke(
        goalId: AwradId,
        activeSlotId: AwradId?,
    ): AllowCountingPastTargetResult {
        val goal = goalRepository.getGoalById(goalId)
            ?: return AllowCountingPastTargetResult.GoalNotFound
        val updatedGoal = goal.allowCountingPastTarget(activeSlotId)
            ?: return AllowCountingPastTargetResult.NotBlockedAtTarget
        val persistedGoal = updatedGoal.copy(updatedAt = System.currentTimeMillis())

        goalRepository.updateGoal(persistedGoal)
        return AllowCountingPastTargetResult.Updated(
            goal = goalRepository.getGoalById(goalId) ?: persistedGoal,
        )
    }
}

internal fun Goal.allowCountingPastTarget(activeSlotId: AwradId?): Goal? {
    val currentActiveSlots = activeSlots

    if (currentActiveSlots.size > 1) {
        val selected = activeSlotId
            ?.let { selectedId -> currentActiveSlots.firstOrNull { it.id == selectedId } }
            ?: return null
        if (selected.capBehavior != CountCapBehavior.BlockAtTarget) return null
        return copy(
            slots = slots.map { slot ->
                if (slot.id == selected.id) {
                    slot.copy(capBehavior = CountCapBehavior.AllowOverTarget)
                } else {
                    slot
                }
            },
        )
    }

    if (currentActiveSlots.size == 1) {
        val onlySlot = currentActiveSlots.single()
        val goalIsBlocked = capBehavior == CountCapBehavior.BlockAtTarget
        val slotIsBlocked = onlySlot.capBehavior == CountCapBehavior.BlockAtTarget
        if (!goalIsBlocked && !slotIsBlocked) return null
        return copy(
            capBehavior = if (goalIsBlocked) CountCapBehavior.AllowOverTarget else capBehavior,
            slots = slots.map { slot ->
                if (slot.id == onlySlot.id && slotIsBlocked) {
                    slot.copy(capBehavior = CountCapBehavior.AllowOverTarget)
                } else {
                    slot
                }
            },
        )
    }

    if (capBehavior != CountCapBehavior.BlockAtTarget) return null
    return copy(capBehavior = CountCapBehavior.AllowOverTarget)
}
