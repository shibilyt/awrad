package app.awrad.awrad_dhikrgoalstracker.ui.screens.counting

import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.util.GoalProgressCalculator
import app.awrad.awrad_dhikrgoalstracker.util.SlotTimeStatus
import app.awrad.awrad_dhikrgoalstracker.util.SlotTimingInfo
import java.time.LocalDate
import java.time.temporal.ChronoUnit

enum class CountingAvailabilityReason(val stableCode: String) {
    FUTURE_START("future_start"),
    OFF_RECURRENCE("off_recurrence"),
    SLOT_UPCOMING("slot_upcoming"),
    SLOT_ENDED("slot_ended"),
    SLOT_TIMING_UNAVAILABLE("slot_timing_unavailable"),
}

enum class CountingHardBlockReason {
    PAUSED,
    COMPLETED,
    EXPIRED,
    DURATION_ENDED,
}

data class CountingConfirmationKey(
    val goalId: AwradId,
    val slotId: AwradId?,
    val effectiveDate: LocalDate,
    val reasons: Set<CountingAvailabilityReason>,
) {
    val persistedValue: String
        get() = listOf(
            effectiveDate.toString(),
            goalId.toString(),
            slotId?.toString() ?: "none",
            reasons.map { it.stableCode }.sorted().joinToString(","),
        ).joinToString(":")
}

sealed interface CountingAvailabilityDecision {
    data object Allow : CountingAvailabilityDecision

    data class RequiresConfirmation(
        val reasons: Set<CountingAvailabilityReason>,
        val key: CountingConfirmationKey,
    ) : CountingAvailabilityDecision

    data class HardBlock(val reason: CountingHardBlockReason) : CountingAvailabilityDecision
}

object CountingAvailabilityPolicy {
    fun evaluate(
        goal: Goal,
        effectiveDate: LocalDate,
        activeSlotId: AwradId?,
        slotTimingInfo: Map<AwradId, SlotTimingInfo>,
    ): CountingAvailabilityDecision {
        if (goal.isCompleted) {
            return CountingAvailabilityDecision.HardBlock(CountingHardBlockReason.COMPLETED)
        }
        if (goal.isPaused) {
            return CountingAvailabilityDecision.HardBlock(CountingHardBlockReason.PAUSED)
        }
        goal.endDate?.let { endDate ->
            if (effectiveDate.isAfter(endDate)) {
                return CountingAvailabilityDecision.HardBlock(CountingHardBlockReason.EXPIRED)
            }
        }
        goal.durationDays?.let { durationDays ->
            if (ChronoUnit.DAYS.between(goal.startDate, effectiveDate) >= durationDays) {
                return CountingAvailabilityDecision.HardBlock(CountingHardBlockReason.DURATION_ENDED)
            }
        }

        val reasons = linkedSetOf<CountingAvailabilityReason>()
        if (effectiveDate.isBefore(goal.startDate)) {
            reasons += CountingAvailabilityReason.FUTURE_START
        } else if (!GoalProgressCalculator.isScheduledOn(goal, effectiveDate)) {
            reasons += CountingAvailabilityReason.OFF_RECURRENCE
        }

        val activeSlot = activeSlotId?.let { id -> goal.activeSlots.firstOrNull { it.id == id } }
        if (activeSlot != null && activeSlot.slotType != GoalSlotType.ANYTIME) {
            when (slotTimingInfo[activeSlot.id]?.timeStatus ?: SlotTimeStatus.UNKNOWN) {
                SlotTimeStatus.ACTIVE,
                SlotTimeStatus.ANYTIME -> Unit
                SlotTimeStatus.UPCOMING -> reasons += CountingAvailabilityReason.SLOT_UPCOMING
                SlotTimeStatus.ENDED -> reasons += CountingAvailabilityReason.SLOT_ENDED
                SlotTimeStatus.UNKNOWN -> reasons += CountingAvailabilityReason.SLOT_TIMING_UNAVAILABLE
            }
        }

        if (reasons.isEmpty()) return CountingAvailabilityDecision.Allow
        return CountingAvailabilityDecision.RequiresConfirmation(
            reasons = reasons,
            key = CountingConfirmationKey(
                goalId = goal.id,
                slotId = activeSlotId,
                effectiveDate = effectiveDate,
                reasons = reasons,
            ),
        )
    }
}
