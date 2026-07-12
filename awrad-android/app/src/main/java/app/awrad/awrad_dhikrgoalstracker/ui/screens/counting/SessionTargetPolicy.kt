package app.awrad.awrad_dhikrgoalstracker.ui.screens.counting

internal object SessionTargetPolicy {
    private const val DefaultCountTarget = 100

    val defaultCountPresets: List<Int> = listOf(33, 100, 500, 1000)

    fun countLimit(targetCount: Int, currentCount: Long): Int? {
        if (targetCount <= 0) return null
        return (targetCount.toLong() - currentCount)
            .coerceAtLeast(0L)
            .coerceAtMost(Int.MAX_VALUE.toLong())
            .toInt()
    }

    fun normalizeCountTarget(requestedValue: Int, remainingLimit: Int?): Int? {
        if (requestedValue <= 0) return null
        if (remainingLimit == null) return requestedValue
        if (remainingLimit <= 0 || requestedValue > remainingLimit) return null
        return requestedValue
    }

    fun defaultCountTarget(remainingLimit: Int?): Int =
        remainingLimit
            ?.takeIf { it > 0 }
            ?.let { minOf(DefaultCountTarget, it) }
            ?: DefaultCountTarget

    fun countPresets(remainingLimit: Int?): List<Int> {
        val limit = remainingLimit?.takeIf { it > 0 }
        val presets = if (limit == null) {
            defaultCountPresets
        } else {
            defaultCountPresets.filter { it <= limit }
        }
        return (presets + listOfNotNull(limit?.takeIf { it !in presets }))
            .distinct()
            .sorted()
    }
}
