package app.awrad.awrad_dhikrgoalstracker.service

import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.util.CountCapCalculator

internal data class CountProgressTransition(
    val targetReached: Boolean,
    val targetReachedNow: Boolean,
    val hardCapReached: Boolean,
)

internal fun evaluateCountProgressTransition(
    previousCount: Long,
    newCount: Long,
    targetCount: Int?,
    maximumCount: Int?,
    capBehavior: CountCapBehavior,
): CountProgressTransition {
    val target = targetCount?.takeIf { it > 0 }?.toLong()
    val targetReached = target != null && newCount >= target
    return CountProgressTransition(
        targetReached = targetReached,
        targetReachedNow = targetReached && previousCount < target,
        hardCapReached = !CountCapCalculator.canApplyIncrement(
            currentCount = newCount,
            targetCount = targetCount?.takeIf { it > 0 },
            maximumCount = maximumCount,
            capBehavior = capBehavior,
        ),
    )
}
