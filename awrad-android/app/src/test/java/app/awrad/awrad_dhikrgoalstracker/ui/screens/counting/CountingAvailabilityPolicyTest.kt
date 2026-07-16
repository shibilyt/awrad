package app.awrad.awrad_dhikrgoalstracker.ui.screens.counting

import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalRecurrence
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.RecurrenceFrequency
import app.awrad.awrad_dhikrgoalstracker.data.model.newAwradId
import app.awrad.awrad_dhikrgoalstracker.util.SlotTimeStatus
import app.awrad.awrad_dhikrgoalstracker.util.SlotTimingInfo
import java.time.DayOfWeek
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CountingAvailabilityPolicyTest {
    private val today = LocalDate.of(2026, 7, 15)

    @Test
    fun `due active and anytime slots allow`() {
        val active = goalWithSlot(GoalSlotType.TIME_WINDOW)
        assertEquals(
            CountingAvailabilityDecision.Allow,
            decision(active, SlotTimeStatus.ACTIVE),
        )
        val anytime = goalWithSlot(GoalSlotType.ANYTIME)
        assertEquals(CountingAvailabilityDecision.Allow, decision(anytime, SlotTimeStatus.ANYTIME))
    }

    @Test
    fun `future start and slot reason combine into one confirmation`() {
        val goal = goalWithSlot(GoalSlotType.TIME_WINDOW).copy(startDate = today.plusDays(2))
        val decision = decision(goal, SlotTimeStatus.UPCOMING)
        assertTrue(decision is CountingAvailabilityDecision.RequiresConfirmation)
        assertEquals(
            setOf(
                CountingAvailabilityReason.FUTURE_START,
                CountingAvailabilityReason.SLOT_UPCOMING,
            ),
            (decision as CountingAvailabilityDecision.RequiresConfirmation).reasons,
        )
    }

    @Test
    fun `off recurrence requires confirmation`() {
        val base = goalWithSlot(GoalSlotType.ANYTIME)
        val goal = base.copy(
            recurrence = GoalRecurrence(
                goalId = base.id,
                frequency = RecurrenceFrequency.WEEKLY,
                weekdays = setOf(DayOfWeek.MONDAY),
            ),
        )
        val decision = decision(goal, SlotTimeStatus.ANYTIME)
        assertEquals(
            setOf(CountingAvailabilityReason.OFF_RECURRENCE),
            (decision as CountingAvailabilityDecision.RequiresConfirmation).reasons,
        )
    }

    @Test
    fun `outside and unknown slot states require confirmation`() {
        listOf(
            SlotTimeStatus.UPCOMING to CountingAvailabilityReason.SLOT_UPCOMING,
            SlotTimeStatus.ENDED to CountingAvailabilityReason.SLOT_ENDED,
            SlotTimeStatus.UNKNOWN to CountingAvailabilityReason.SLOT_TIMING_UNAVAILABLE,
        ).forEach { (status, reason) ->
            val decision = decision(goalWithSlot(GoalSlotType.TIME_WINDOW), status)
            assertEquals(
                setOf(reason),
                (decision as CountingAvailabilityDecision.RequiresConfirmation).reasons,
            )
        }
    }

    @Test
    fun `paused completed expired and duration ended hard block`() {
        val base = goalWithSlot(GoalSlotType.ANYTIME)
        assertEquals(
            CountingAvailabilityDecision.HardBlock(CountingHardBlockReason.PAUSED),
            decision(base.copy(isActive = false), SlotTimeStatus.ANYTIME),
        )
        assertEquals(
            CountingAvailabilityDecision.HardBlock(CountingHardBlockReason.COMPLETED),
            decision(base.copy(isActive = false, completedAt = 1L), SlotTimeStatus.ANYTIME),
        )
        assertEquals(
            CountingAvailabilityDecision.HardBlock(CountingHardBlockReason.EXPIRED),
            decision(base.copy(endDate = today.minusDays(1)), SlotTimeStatus.ANYTIME),
        )
        assertEquals(
            CountingAvailabilityDecision.HardBlock(CountingHardBlockReason.DURATION_ENDED),
            decision(base.copy(startDate = today.minusDays(2), durationDays = 2), SlotTimeStatus.ANYTIME),
        )
    }

    @Test
    fun `confirmation key changes with slot reason and effective date`() {
        val goal = goalWithSlot(GoalSlotType.TIME_WINDOW)
        val upcoming = decision(goal, SlotTimeStatus.UPCOMING).confirmationKey()
        val ended = decision(goal, SlotTimeStatus.ENDED).confirmationKey()
        val tomorrow = decision(goal, SlotTimeStatus.UPCOMING, today.plusDays(1)).confirmationKey()
        assertTrue(upcoming.persistedValue != ended.persistedValue)
        assertTrue(upcoming.persistedValue != tomorrow.persistedValue)
    }

    private fun goalWithSlot(type: GoalSlotType): Goal {
        val goalId = newAwradId()
        val slot = GoalSlot(
            id = newAwradId(),
            goalId = goalId,
            slotType = type,
            startMinute = if (type == GoalSlotType.TIME_WINDOW) 9 * 60 else null,
            endMinute = if (type == GoalSlotType.TIME_WINDOW) 10 * 60 else null,
            targetCount = 10,
        )
        return Goal(
            id = goalId,
            dhikrId = newAwradId(),
            slots = listOf(slot),
            recurrence = GoalRecurrence(goalId = goalId),
            startDate = today.minusDays(1),
        )
    }

    private fun decision(
        goal: Goal,
        status: SlotTimeStatus,
        date: LocalDate = today,
    ): CountingAvailabilityDecision {
        val slot = goal.activeSlots.first()
        return CountingAvailabilityPolicy.evaluate(
            goal = goal,
            effectiveDate = date,
            activeSlotId = slot.id,
            slotTimingInfo = mapOf(slot.id to SlotTimingInfo(timeStatus = status)),
        )
    }

    private fun CountingAvailabilityDecision.confirmationKey(): CountingConfirmationKey =
        (this as CountingAvailabilityDecision.RequiresConfirmation).key
}
