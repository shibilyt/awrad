package app.awrad.awrad_dhikrgoalstracker.util

import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior

data class CountCapResult(
    val appliedDelta: Long,
    val reason: CountCapReason = CountCapReason.Allowed,
    val wouldCrossTarget: Boolean = false,
) {
    val isBlocked: Boolean
        get() = reason == CountCapReason.BlockedAtTarget ||
            reason == CountCapReason.BlockedAtMaximum
}

enum class CountCapReason {
    Allowed,
    WarnedOverTarget,
    ClampedAtTarget,
    ClampedAtMaximum,
    BlockedAtTarget,
    BlockedAtMaximum,
    Decremented,
    NoOp,
}

object CountCapCalculator {

    fun remainingCapacity(
        currentCount: Long,
        targetCount: Int?,
        maximumCount: Int?,
        capBehavior: CountCapBehavior,
    ): Long? {
        val cap = when (capBehavior) {
            CountCapBehavior.AllowOverTarget,
            CountCapBehavior.WarnOverTarget -> null
            CountCapBehavior.BlockAtTarget -> targetCount?.toLong()
            CountCapBehavior.BlockAtMaximum -> maximumCount?.toLong()
        }
        return cap?.minus(currentCount)?.coerceAtLeast(0L)
    }

    fun canApplyIncrement(
        currentCount: Long,
        targetCount: Int?,
        maximumCount: Int?,
        capBehavior: CountCapBehavior,
    ): Boolean = applyDelta(
        currentCount = currentCount,
        requestedDelta = 1L,
        targetCount = targetCount,
        maximumCount = maximumCount,
        capBehavior = capBehavior,
    ).appliedDelta > 0L

    fun applyDelta(
        currentCount: Long,
        requestedDelta: Long,
        targetCount: Int?,
        maximumCount: Int?,
        capBehavior: CountCapBehavior,
    ): CountCapResult {
        if (requestedDelta == 0L) {
            return CountCapResult(appliedDelta = 0L, reason = CountCapReason.NoOp)
        }
        if (requestedDelta < 0L) {
            return CountCapResult(
                appliedDelta = requestedDelta.coerceAtLeast(-currentCount),
                reason = CountCapReason.Decremented,
            )
        }

        val wouldCrossTarget = targetCount != null &&
            currentCount <= targetCount &&
            currentCount + requestedDelta > targetCount

        val capTarget = when (capBehavior) {
            CountCapBehavior.AllowOverTarget,
            CountCapBehavior.WarnOverTarget -> null
            CountCapBehavior.BlockAtTarget -> targetCount
            CountCapBehavior.BlockAtMaximum -> maximumCount
        }
        val cap = capTarget?.toLong()

        val applied = if (cap == null) {
            requestedDelta
        } else {
            requestedDelta.coerceAtMost(cap - currentCount).coerceAtLeast(0L)
        }
        val reason = when {
            capBehavior == CountCapBehavior.WarnOverTarget && wouldCrossTarget -> CountCapReason.WarnedOverTarget
            applied == requestedDelta -> CountCapReason.Allowed
            capBehavior == CountCapBehavior.BlockAtTarget && applied == 0L -> CountCapReason.BlockedAtTarget
            capBehavior == CountCapBehavior.BlockAtMaximum && applied == 0L -> CountCapReason.BlockedAtMaximum
            capBehavior == CountCapBehavior.BlockAtTarget -> CountCapReason.ClampedAtTarget
            capBehavior == CountCapBehavior.BlockAtMaximum -> CountCapReason.ClampedAtMaximum
            else -> CountCapReason.Allowed
        }
        return CountCapResult(
            appliedDelta = applied,
            reason = reason,
            wouldCrossTarget = capBehavior == CountCapBehavior.WarnOverTarget && wouldCrossTarget,
        )
    }
}
