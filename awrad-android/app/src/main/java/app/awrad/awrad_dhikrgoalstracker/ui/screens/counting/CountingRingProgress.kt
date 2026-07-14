package app.awrad.awrad_dhikrgoalstracker.ui.screens.counting

internal data class CountingRingProgress(
    val minimum: Float,
    val maximum: Float,
)

internal fun countingRingUpperBound(
    targetCount: Int?,
    maximumCount: Int?,
): Int? = maximumCount?.takeIf { it > 0 } ?: targetCount?.takeIf { it > 0 }

internal fun countingRingProgress(
    currentCount: Long,
    minimumCount: Int,
    maximumCount: Int,
): CountingRingProgress {
    require(minimumCount > 0) { "minimumCount must be positive" }
    require(maximumCount >= minimumCount) { "maximumCount must be at least minimumCount" }

    return CountingRingProgress(
        minimum = (currentCount.toFloat() / minimumCount).coerceIn(0f, 1f),
        maximum = (currentCount.toFloat() / maximumCount).coerceIn(0f, 1f),
    )
}
