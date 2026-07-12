package app.awrad.awrad_dhikrgoalstracker.data.model.wird

/**
 * Runtime progress for one part, on one day, for one occasion. Uniquely identified by the tuple
 * (wirdID, partID, occasionKey, dateKey). Progress is keyed by stable segment UUID strings so that
 * editing a custom wird never corrupts past completion or streaks.
 */
data class WirdSession(
    val wirdID: String,
    val partID: String,
    val occasionKey: String = WirdOccasion.Anytime.key,
    val dateKey: String,
    /** key = segment id, value = current count. */
    val segmentProgress: Map<String, Int> = emptyMap(),
    val lastSegmentID: String? = null,
    val isComplete: Boolean = false,
    val startedAt: Long = 0L,
    val completedAt: Long? = null,
) {
    fun count(segmentID: String): Int = segmentProgress[segmentID] ?: 0
}

data class ProgressSummary(
    val completedItems: Int,
    val totalItems: Int,
) {
    val progress: Float
        get() = if (totalItems <= 0) 0f else minOf(completedItems.toFloat() / totalItems, 1f)

    val isComplete: Boolean get() = totalItems > 0 && completedItems >= totalItems
}
