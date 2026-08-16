package app.awrad.awrad_dhikrgoalstracker.util

import app.awrad.awrad_dhikrgoalstracker.data.model.CountEntry
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import kotlin.math.roundToLong

data class GoalSessionStats(
    val slot: GoalSlot,
    val totalCount: Long = 0L,
    val activeDays: Int = 0,
    val averageActiveDayCount: Long = 0L,
    val sharePercent: Int = 0,
)

object GoalSessionStatsCalculator {
    fun calculate(
        historyItems: List<CountEntry>,
        slots: List<GoalSlot>,
    ): List<GoalSessionStats> {
        val positiveEntries = historyItems.filter { it.count > 0L }
        val totalCount = positiveEntries.sumOf { it.count }
        return slots
            .filter { it.isActive }
            .sortedBy { it.sortOrder }
            .map { slot ->
                val slotEntries = positiveEntries.filter { it.slotId == slot.id }
                val slotTotal = slotEntries.sumOf { it.count }
                GoalSessionStats(
                    slot = slot,
                    totalCount = slotTotal,
                    activeDays = slotEntries.map { it.date }.distinct().size,
                    averageActiveDayCount = if (slotEntries.isEmpty()) 0L else {
                        (slotTotal.toDouble() / slotEntries.map { it.date }.distinct().size).roundToLong()
                    },
                    sharePercent = if (totalCount == 0L) 0 else {
                        (slotTotal * 100.0 / totalCount).toInt()
                    },
                )
            }
    }
}
