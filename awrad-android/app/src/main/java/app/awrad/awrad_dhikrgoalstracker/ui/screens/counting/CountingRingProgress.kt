package app.awrad.awrad_dhikrgoalstracker.ui.screens.counting

internal data class CountingRingProgress(
    val progress: Float,
    val minimumSegmentProgress: Float,
    val remainingSegmentProgress: Float,
    val minimumCheckpoint: Float,
    val activeTarget: Int,
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

    val activeTarget = if (currentCount < minimumCount) minimumCount else maximumCount
    val progress = (currentCount.toFloat() / activeTarget).coerceIn(0f, 1f)
    val minimumCheckpoint = (minimumCount.toFloat() / maximumCount).coerceIn(0f, 1f)
    val hasReachedMinimum = currentCount >= minimumCount

    return CountingRingProgress(
        progress = progress,
        minimumSegmentProgress = if (hasReachedMinimum) minimumCheckpoint else progress,
        remainingSegmentProgress = if (hasReachedMinimum) {
            (progress - minimumCheckpoint).coerceIn(0f, 1f)
        } else {
            0f
        },
        minimumCheckpoint = minimumCheckpoint,
        activeTarget = activeTarget,
    )
}
