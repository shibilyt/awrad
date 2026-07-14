package app.awrad.awrad_dhikrgoalstracker.ui.screens.counting

import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId

import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.SlotCountingPolicy
import app.awrad.awrad_dhikrgoalstracker.util.SlotTimeStatus
import app.awrad.awrad_dhikrgoalstracker.util.SlotTimingInfo

data class SlotCountingUiModel(
    val id: AwradId,
    val title: String,
    val subtitle: String,
    val count: Long,
    val target: Int,
    val progress: Float,
    val timeStatus: SlotTimeStatus = SlotTimeStatus.UNKNOWN,
    val startText: String = "",
    val endText: String = "",
    val isRecommended: Boolean = false,
    val isActive: Boolean,
    val isComplete: Boolean,
    val isSelectable: Boolean,
    val canSelect: Boolean = isSelectable,
    val canCountNow: Boolean = true,
    val requiresEndedWarning: Boolean = false,
)

internal fun List<GoalSlot>.usesSlotProgress(): Boolean =
    any { it.slotType != GoalSlotType.ANYTIME } || size > 1

internal fun List<GoalSlot>.hasSelectableSlots(): Boolean =
    usesSlotProgress() && size > 1

internal fun List<GoalSlot>.totalSlotTarget(): Int =
    sumOf { it.targetCount ?: 0 }

internal fun Map<AwradId, Long>.totalForSlots(slots: List<GoalSlot>): Long =
    slots.sumOf { this[it.id] ?: 0L }

data class DefaultSlotSelection(
    val slotId: AwradId?,
    val source: SlotSelectionSource,
)

enum class SlotSelectionSource {
    NONE,
    INITIAL,
    RESTORED,
    ACTIVE_TIME,
    COUNTED_ENDED,
    UPCOMING,
    FALLBACK,
}

internal fun selectDefaultSlot(
    slots: List<GoalSlot>,
    slotCounts: Map<AwradId, Long>,
    timingInfoBySlotId: Map<AwradId, SlotTimingInfo>,
    initialSlotId: AwradId?,
    restoredSlotId: AwradId?,
): DefaultSlotSelection {
    if (slots.isEmpty() || !slots.usesSlotProgress()) return DefaultSlotSelection(null, SlotSelectionSource.NONE)

    initialSlotId
        ?.takeIf { requested -> slots.any { it.id == requested } }
        ?.let { return DefaultSlotSelection(it, SlotSelectionSource.INITIAL) }

    restoredSlotId
        ?.takeIf { requested -> slots.any { it.id == requested } }
        ?.let { return DefaultSlotSelection(it, SlotSelectionSource.RESTORED) }

    slots
        .filter { timingInfoBySlotId[it.id]?.timeStatus == SlotTimeStatus.ACTIVE }
        .maxWithOrNull(compareBy<GoalSlot> { timingInfoBySlotId[it.id]?.startsAtMillis ?: Long.MIN_VALUE }
            .thenByDescending { -it.sortOrder })
        ?.let { return DefaultSlotSelection(it.id, SlotSelectionSource.ACTIVE_TIME) }

    slots
        .filter { slot ->
            val target = slot.targetCount ?: 0
            val count = slotCounts[slot.id] ?: 0L
            timingInfoBySlotId[slot.id]?.timeStatus == SlotTimeStatus.ENDED &&
                count > 0L &&
                (target <= 0 || count < target)
        }
        .minByOrNull { it.sortOrder }
        ?.let { return DefaultSlotSelection(it.id, SlotSelectionSource.COUNTED_ENDED) }

    slots
        .filter { slot ->
            val target = slot.targetCount ?: 0
            val count = slotCounts[slot.id] ?: 0L
            timingInfoBySlotId[slot.id]?.timeStatus == SlotTimeStatus.UPCOMING &&
                (target <= 0 || count < target)
        }
        .minWithOrNull(compareBy<GoalSlot> { timingInfoBySlotId[it.id]?.startsAtMillis ?: Long.MAX_VALUE }
            .thenBy { it.sortOrder })
        ?.let { return DefaultSlotSelection(it.id, SlotSelectionSource.UPCOMING) }

    slots
        .filter { slot ->
            val target = slot.targetCount ?: 0
            val count = slotCounts[slot.id] ?: 0L
            timingInfoBySlotId[slot.id]?.timeStatus == SlotTimeStatus.ENDED &&
                (target <= 0 || count < target)
        }
        .maxWithOrNull(compareBy<GoalSlot> { timingInfoBySlotId[it.id]?.endsAtMillis ?: Long.MIN_VALUE }
            .thenBy { it.sortOrder })
        ?.let { return DefaultSlotSelection(it.id, SlotSelectionSource.FALLBACK) }

    slots
        .firstOrNull { slot ->
            val target = slot.targetCount ?: 0
            val count = slotCounts[slot.id] ?: 0L
            target <= 0 || count < target
        }
        ?.let { return DefaultSlotSelection(it.id, SlotSelectionSource.FALLBACK) }

    return DefaultSlotSelection(slots.firstOrNull()?.id, SlotSelectionSource.FALLBACK)
}

internal fun buildSlotCountingUiModels(
    slots: List<GoalSlot>,
    slotCounts: Map<AwradId, Long>,
    activeSlotId: AwradId?,
    timingInfoBySlotId: Map<AwradId, SlotTimingInfo> = emptyMap(),
    recommendedSlotId: AwradId? = null,
    slotCountingPolicy: SlotCountingPolicy = SlotCountingPolicy.WARN_AND_ALLOW,
    titleForSlot: (GoalSlot) -> String,
    subtitleForSlot: (GoalSlot) -> String,
): List<SlotCountingUiModel> {
    val isSelectable = slots.hasSelectableSlots()
    return slots.map { slot ->
        val count = slotCounts[slot.id] ?: 0L
        val target = slot.targetCount ?: 0
        val progress = if (target > 0) {
            (count.toFloat() / target).coerceIn(0f, 1f)
        } else {
            0f
        }
        val timing = timingInfoBySlotId[slot.id] ?: SlotTimingInfo(
            timeStatus = if (slot.slotType == GoalSlotType.ANYTIME) SlotTimeStatus.ANYTIME else SlotTimeStatus.UNKNOWN,
        )
        val isComplete = target > 0 && count >= target
        val canCountNow = when (slotCountingPolicy) {
            SlotCountingPolicy.STRICT_ACTIVE_ONLY -> timing.timeStatus == SlotTimeStatus.ACTIVE ||
                timing.timeStatus == SlotTimeStatus.ANYTIME
            SlotCountingPolicy.WARN_AND_ALLOW,
            SlotCountingPolicy.SILENT_FLEXIBLE -> true
        }
        val canSelect = isSelectable && when (slotCountingPolicy) {
            SlotCountingPolicy.STRICT_ACTIVE_ONLY -> canCountNow
            SlotCountingPolicy.WARN_AND_ALLOW,
            SlotCountingPolicy.SILENT_FLEXIBLE -> true
        }
        SlotCountingUiModel(
            id = slot.id,
            title = titleForSlot(slot),
            subtitle = subtitleForSlot(slot),
            count = count,
            target = target,
            progress = progress,
            timeStatus = timing.timeStatus,
            startText = timing.startText,
            endText = timing.endText,
            isRecommended = recommendedSlotId == slot.id,
            isActive = activeSlotId == slot.id,
            isComplete = isComplete,
            isSelectable = isSelectable,
            canSelect = canSelect,
            canCountNow = canCountNow,
            requiresEndedWarning = slotCountingPolicy == SlotCountingPolicy.WARN_AND_ALLOW &&
                timing.timeStatus == SlotTimeStatus.ENDED &&
                !isComplete,
        )
    }
}
