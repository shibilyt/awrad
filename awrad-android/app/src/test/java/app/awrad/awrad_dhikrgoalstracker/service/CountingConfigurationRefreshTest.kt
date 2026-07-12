package app.awrad.awrad_dhikrgoalstracker.service

import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CountingConfigurationRefreshTest {

    @Test
    fun `same goal refresh replaces stale slot list and keeps valid active slot`() {
        val current = CountingState(
            goalId = 1,
            currentCount = 3,
            targetCount = 100,
            slots = listOf(slot(id = 10, target = 100)),
            slotCounts = mapOf(10L to 3L),
            activeSlotId = 10,
        )
        val refreshed = current.refreshedWithGoalConfiguration(
            targetCount = 200,
            maximumCount = null,
            capBehavior = CountCapBehavior.AllowOverTarget,
            currentCount = 3,
            dhikrArabic = "dhikr",
            dhikrTransliteration = "Dhikr",
            audioCountPerPlay = 1,
            isPrayerBased = false,
            slots = listOf(slot(id = 10, target = 100), slot(id = 11, target = 100)),
            slotCounts = mapOf(10L to 3L, 11L to 0L),
            activeSlotId = 10,
        )

        assertEquals(listOf(10L, 11L), refreshed.state.slots.map { it.id })
        assertEquals(10L, refreshed.state.activeSlotId)
        assertEquals(100, refreshed.state.targetCount)
        assertEquals(3L, refreshed.state.currentCount)
        assertFalse(refreshed.shouldStopAudio)
    }

    @Test
    fun `same goal refresh switches active slot and requests audio stop when previous slot is archived`() {
        val current = CountingState(
            goalId = 1,
            currentCount = 4,
            targetCount = 100,
            isAudioMode = true,
            isPlaying = true,
            slots = listOf(slot(id = 10, target = 100), slot(id = 11, target = 100)),
            slotCounts = mapOf(10L to 4L, 11L to 0L),
            activeSlotId = 10,
        )
        val refreshed = current.refreshedWithGoalConfiguration(
            targetCount = 100,
            maximumCount = 125,
            capBehavior = CountCapBehavior.WarnOverTarget,
            currentCount = 0,
            dhikrArabic = "dhikr",
            dhikrTransliteration = "Dhikr",
            audioCountPerPlay = 1,
            isPrayerBased = false,
            slots = listOf(slot(id = 11, target = 100, maximum = 125, cap = CountCapBehavior.WarnOverTarget)),
            slotCounts = mapOf(11L to 7L),
            activeSlotId = 11,
        )

        assertEquals(listOf(11L), refreshed.state.slots.map { it.id })
        assertEquals(11L, refreshed.state.activeSlotId)
        assertEquals(7L, refreshed.state.currentCount)
        assertEquals(100, refreshed.state.targetCount)
        assertEquals(125, refreshed.state.maximumCount)
        assertEquals(CountCapBehavior.WarnOverTarget, refreshed.state.capBehavior)
        assertTrue(refreshed.shouldStopAudio)
    }

    private fun slot(
        id: Long,
        target: Int,
        maximum: Int? = null,
        cap: CountCapBehavior = CountCapBehavior.AllowOverTarget,
    ) = GoalSlot(
        id = id,
        goalId = 1,
        slotType = GoalSlotType.TIME_WINDOW,
        targetCount = target,
        maximumCount = maximum,
        capBehavior = cap,
    )
}
