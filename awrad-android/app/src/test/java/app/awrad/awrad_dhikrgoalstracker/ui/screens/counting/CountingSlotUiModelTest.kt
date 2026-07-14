package app.awrad.awrad_dhikrgoalstracker.ui.screens.counting

import app.awrad.awrad_dhikrgoalstracker.testId

import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.SlotCountingPolicy
import app.awrad.awrad_dhikrgoalstracker.util.SlotTimeStatus
import app.awrad.awrad_dhikrgoalstracker.util.SlotTimingInfo
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CountingSlotUiModelTest {

    @Test
    fun `single anytime slot keeps the non-slot counting path`() {
        val slots = listOf(
            GoalSlot(
                id = testId(1),
                goalId = testId(7),
                slotType = GoalSlotType.ANYTIME,
                targetCount = 100,
            ),
        )

        assertFalse(slots.usesSlotProgress())
        assertFalse(slots.hasSelectableSlots())
    }

    @Test
    fun `multiple time window slots are selectable and expose progress`() {
        val slots = listOf(
            GoalSlot(
                id = testId(1),
                goalId = testId(7),
                slotType = GoalSlotType.TIME_WINDOW,
                targetCount = 50,
                label = "Morning",
            ),
            GoalSlot(
                id = testId(2),
                goalId = testId(7),
                slotType = GoalSlotType.TIME_WINDOW,
                targetCount = 50,
                label = "Evening",
            ),
        )

        val models = buildSlotCountingUiModels(
            slots = slots,
            slotCounts = mapOf(testId(1) to 50L, testId(2) to 22L),
            activeSlotId = testId(2),
            titleForSlot = { it.label.orEmpty() },
            subtitleForSlot = { "" },
        )

        assertTrue(slots.usesSlotProgress())
        assertTrue(slots.hasSelectableSlots())
        assertEquals(2, models.size)
        assertTrue(models[0].isComplete)
        assertFalse(models[0].isActive)
        assertEquals(1f, models[0].progress, 0.001f)
        assertTrue(models[1].isActive)
        assertFalse(models[1].isComplete)
        assertEquals(0.44f, models[1].progress, 0.001f)
    }

    @Test
    fun `single time window slot uses active slot progress without chips`() {
        val slots = listOf(
            GoalSlot(
                id = testId(3),
                goalId = testId(7),
                slotType = GoalSlotType.TIME_WINDOW,
                targetCount = 33,
                label = "Night",
            ),
        )

        val model = buildSlotCountingUiModels(
            slots = slots,
            slotCounts = mapOf(testId(3) to 11L),
            activeSlotId = testId(3),
            titleForSlot = { it.label.orEmpty() },
            subtitleForSlot = { "" },
        ).single()

        assertTrue(slots.usesSlotProgress())
        assertFalse(slots.hasSelectableSlots())
        assertTrue(model.isActive)
        assertFalse(model.isSelectable)
        assertEquals(11L, model.count)
        assertEquals(33, model.target)
    }

    @Test
    fun `default selection prefers active slot even when complete`() {
        val slots = timeSlots()

        val selection = selectDefaultSlot(
            slots = slots,
            slotCounts = mapOf(testId(1) to 50L, testId(2) to 0L),
            timingInfoBySlotId = mapOf(
                testId(1) to SlotTimingInfo(timeStatus = SlotTimeStatus.ACTIVE, startsAtMillis = 1000),
                testId(2) to SlotTimingInfo(timeStatus = SlotTimeStatus.UPCOMING, startsAtMillis = 2000),
            ),
            initialSlotId = null,
            restoredSlotId = null,
        )

        assertEquals(testId(1), selection.slotId)
        assertEquals(SlotSelectionSource.ACTIVE_TIME, selection.source)
    }

    @Test
    fun `default selection preserves restored service slot`() {
        val slots = timeSlots()

        val selection = selectDefaultSlot(
            slots = slots,
            slotCounts = emptyMap(),
            timingInfoBySlotId = mapOf(testId(1) to SlotTimingInfo(timeStatus = SlotTimeStatus.ACTIVE)),
            initialSlotId = null,
            restoredSlotId = testId(2),
        )

        assertEquals(testId(2), selection.slotId)
        assertEquals(SlotSelectionSource.RESTORED, selection.source)
    }

    @Test
    fun `default selection prefers counted ended incomplete before upcoming`() {
        val slots = timeSlots()

        val selection = selectDefaultSlot(
            slots = slots,
            slotCounts = mapOf(testId(1) to 10L, testId(2) to 0L),
            timingInfoBySlotId = mapOf(
                testId(1) to SlotTimingInfo(timeStatus = SlotTimeStatus.ENDED, startsAtMillis = 1000),
                testId(2) to SlotTimingInfo(timeStatus = SlotTimeStatus.UPCOMING, startsAtMillis = 2000),
            ),
            initialSlotId = null,
            restoredSlotId = null,
        )

        assertEquals(testId(1), selection.slotId)
        assertEquals(SlotSelectionSource.COUNTED_ENDED, selection.source)
    }

    @Test
    fun `default selection falls back to latest ended incomplete slot when all windows are over`() {
        val slots = timeSlots()

        val selection = selectDefaultSlot(
            slots = slots,
            slotCounts = emptyMap(),
            timingInfoBySlotId = mapOf(
                testId(1) to SlotTimingInfo(
                    timeStatus = SlotTimeStatus.ENDED,
                    startsAtMillis = 9 * 60 * 60_000L,
                    endsAtMillis = 10 * 60 * 60_000L,
                ),
                testId(2) to SlotTimingInfo(
                    timeStatus = SlotTimeStatus.ENDED,
                    startsAtMillis = 10 * 60 * 60_000L,
                    endsAtMillis = 11 * 60 * 60_000L,
                ),
            ),
            initialSlotId = null,
            restoredSlotId = null,
        )

        assertEquals(testId(2), selection.slotId)
        assertEquals(SlotSelectionSource.FALLBACK, selection.source)
    }

    @Test
    fun `notification initial slot wins`() {
        val slots = timeSlots()

        val selection = selectDefaultSlot(
            slots = slots,
            slotCounts = emptyMap(),
            timingInfoBySlotId = mapOf(testId(1) to SlotTimingInfo(timeStatus = SlotTimeStatus.ACTIVE)),
            initialSlotId = testId(2),
            restoredSlotId = testId(1),
        )

        assertEquals(testId(2), selection.slotId)
        assertEquals(SlotSelectionSource.INITIAL, selection.source)
    }

    @Test
    fun `strict policy blocks positive count outside active slot in ui model`() {
        val slot = timeSlots().first()

        val strict = buildSlotCountingUiModels(
            slots = listOf(slot),
            slotCounts = mapOf(slot.id to 10L),
            activeSlotId = slot.id,
            timingInfoBySlotId = mapOf(slot.id to SlotTimingInfo(timeStatus = SlotTimeStatus.ENDED)),
            slotCountingPolicy = SlotCountingPolicy.STRICT_ACTIVE_ONLY,
            titleForSlot = { it.label.orEmpty() },
            subtitleForSlot = { "" },
        ).single()

        assertFalse(strict.canCountNow)
    }

    @Test
    fun `warn and silent policies allow ended slot with warning flag only for warn`() {
        val slot = timeSlots().first()

        val warn = buildSlotCountingUiModels(
            slots = listOf(slot),
            slotCounts = mapOf(slot.id to 10L),
            activeSlotId = slot.id,
            timingInfoBySlotId = mapOf(slot.id to SlotTimingInfo(timeStatus = SlotTimeStatus.ENDED)),
            slotCountingPolicy = SlotCountingPolicy.WARN_AND_ALLOW,
            titleForSlot = { it.label.orEmpty() },
            subtitleForSlot = { "" },
        ).single()
        val silent = buildSlotCountingUiModels(
            slots = listOf(slot),
            slotCounts = mapOf(slot.id to 10L),
            activeSlotId = slot.id,
            timingInfoBySlotId = mapOf(slot.id to SlotTimingInfo(timeStatus = SlotTimeStatus.ENDED)),
            slotCountingPolicy = SlotCountingPolicy.SILENT_FLEXIBLE,
            titleForSlot = { it.label.orEmpty() },
            subtitleForSlot = { "" },
        ).single()

        assertTrue(warn.canCountNow)
        assertTrue(warn.requiresEndedWarning)
        assertTrue(silent.canCountNow)
        assertFalse(silent.requiresEndedWarning)
    }

    private fun timeSlots(): List<GoalSlot> = listOf(
        GoalSlot(
            id = testId(1),
            goalId = testId(7),
            slotType = GoalSlotType.TIME_WINDOW,
            targetCount = 50,
            label = "Morning",
            sortOrder = 0,
        ),
        GoalSlot(
            id = testId(2),
            goalId = testId(7),
            slotType = GoalSlotType.TIME_WINDOW,
            targetCount = 50,
            label = "Evening",
            sortOrder = 1,
        ),
    )
}
