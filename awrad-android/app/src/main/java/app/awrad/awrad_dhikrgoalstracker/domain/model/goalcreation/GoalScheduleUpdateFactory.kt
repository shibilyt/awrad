package app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation

import app.awrad.awrad_dhikrgoalstracker.data.model.CalendarSystem
import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalRecurrence
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSpecificDate
import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.PrayerRelation
import app.awrad.awrad_dhikrgoalstracker.data.model.RecurrenceFrequency
import app.awrad.awrad_dhikrgoalstracker.data.model.ReminderType
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy

object GoalScheduleUpdateFactory {

    fun update(existingGoal: Goal, command: UpdateGoalScheduleCommand): GoalUpdateResult {
        val errors = mutableListOf<GoalUpdateError>()
        if (command.goalId != existingGoal.id) errors += GoalUpdateError.GoalIdMismatch
        if (!command.schedule.isValid()) errors += GoalUpdateError.InvalidSchedule

        val activeById = existingGoal.slots.filter { it.id > 0 }.associateBy { it.id }
        val activeSlots = command.timing.toActiveSlots(
            existingGoal = existingGoal,
            activeById = activeById,
            errors = errors,
        )
        if (activeSlots.isEmpty()) {
            errors += GoalUpdateError.CannotRemoveLastSlot
        }
        if (errors.isNotEmpty()) {
            return GoalUpdateResult.Invalid(errors.distinct())
        }

        val retainedExistingIds = activeSlots.mapNotNull { it.id.takeIf { id -> id > 0 } }.toSet()
        val newlyArchived = existingGoal.slots
            .filter { it.id > 0 && it.id !in retainedExistingIds }
            .map {
                it.copy(
                    isActive = false,
                    archivedAt = it.archivedAt ?: command.archivedAtMillis,
                )
            }
        val archivedSlots = (existingGoal.archivedSlots + newlyArchived)
            .distinctBy { it.id }
            .sortedWith(compareBy<GoalSlot> { it.archivedAt ?: Long.MAX_VALUE }.thenBy { it.sortOrder })
        val activeSlotIds = activeSlots.mapNotNull { it.id.takeIf { id -> id > 0 } }.toSet()
        val reminders = existingGoal.reminders.filter { reminder ->
            reminder.slotId == null ||
                reminder.slotId in activeSlotIds ||
                reminder.reminderType == ReminderType.FIXED_TIME
        }.map { reminder ->
            if (reminder.slotId != null && reminder.slotId !in activeSlotIds) {
                reminder.copy(slotId = null)
            } else {
                reminder
            }
        }

        val updatedGoal = existingGoal.copy(
            recurrence = command.schedule.toRecurrence(existingGoal.startDate),
            slots = activeSlots,
            archivedSlots = archivedSlots,
            reminders = reminders,
            minimumStreakCount = activeSlots.aggregateMinimumCount(existingGoal.minimumStreakCount),
            maximumCount = activeSlots.aggregateMaximumCount(existingGoal.maximumCount),
            capBehavior = activeSlots.aggregateCapBehavior(existingGoal.capBehavior),
        )
        return GoalUpdateResult.Valid(ValidatedGoalUpdate(updatedGoal))
    }

    private fun ScheduleSpec.isValid(): Boolean =
        when (this) {
            ScheduleSpec.Daily -> true
            is ScheduleSpec.Weekly -> weekdays.isNotEmpty()
            is ScheduleSpec.Monthly -> daysOfMonth.isNotEmpty() && daysOfMonth.all { it in 1..31 }
            is ScheduleSpec.Interval -> intervalDays > 0
            is ScheduleSpec.Yearly -> month in 1..12 &&
                daysOfMonth.isNotEmpty() &&
                daysOfMonth.all { it in 1..31 }
            is ScheduleSpec.Season -> true
            is ScheduleSpec.SpecificDates -> dates.isNotEmpty()
        }

    private fun ScheduleSpec.toRecurrence(startDate: java.time.LocalDate): GoalRecurrence =
        when (this) {
            ScheduleSpec.Daily -> GoalRecurrence(frequency = RecurrenceFrequency.DAILY)
            is ScheduleSpec.Weekly -> GoalRecurrence(
                frequency = RecurrenceFrequency.WEEKLY,
                weekdays = weekdays,
            )
            is ScheduleSpec.Monthly -> GoalRecurrence(
                frequency = RecurrenceFrequency.MONTHLY,
                calendar = calendar,
                monthDays = daysOfMonth,
            )
            is ScheduleSpec.Interval -> GoalRecurrence(
                frequency = RecurrenceFrequency.INTERVAL,
                intervalDays = intervalDays,
                anchorDate = anchorDate ?: startDate,
            )
            is ScheduleSpec.Yearly -> GoalRecurrence(
                frequency = RecurrenceFrequency.YEARLY,
                calendar = calendar,
                month = month,
                monthDays = daysOfMonth,
            )
            is ScheduleSpec.Season -> GoalRecurrence(
                frequency = RecurrenceFrequency.SEASON,
                calendar = CalendarSystem.HIJRI,
                seasonTemplateCode = templateCode,
            )
            is ScheduleSpec.SpecificDates -> GoalRecurrence(
                frequency = RecurrenceFrequency.SPECIFIC_DATES,
                specificDates = dates.map { GoalSpecificDate(date = it) }.toSet(),
            )
        }

    private fun ScheduleTimingUpdate.toActiveSlots(
        existingGoal: Goal,
        activeById: Map<Long, GoalSlot>,
        errors: MutableList<GoalUpdateError>,
    ): List<GoalSlot> {
        val requestedIds = requestedSlotIds()
        if (requestedIds.size != requestedIds.distinct().size) {
            errors += GoalUpdateError.DuplicateSlotPolicy
        }
        if (requestedIds.any { it !in activeById }) {
            errors += GoalUpdateError.UnknownSlotPolicy
        }
        return when (this) {
            is ScheduleTimingUpdate.Anytime -> {
                val retained = slotId?.let { activeById[it] }
                    ?: existingGoal.slots.firstOrNull { it.slotType == GoalSlotType.ANYTIME }
                listOf(
                    (retained ?: existingGoal.newSlotDefaults()).copy(
                        slotType = GoalSlotType.ANYTIME,
                        prayerName = null,
                        prayerRelation = null,
                        startMinute = null,
                        endMinute = null,
                        startLeadMinutesOverride = null,
                        label = label?.trim()?.takeIf { it.isNotBlank() },
                        sortOrder = 0,
                        isActive = true,
                        archivedAt = null,
                    )
                )
            }
            is ScheduleTimingUpdate.PrayerBased -> {
                if (slots.isEmpty()) errors += GoalUpdateError.InvalidTiming
                if (slots.distinctBy { it.prayer to it.relation }.size != slots.size) {
                    errors += GoalUpdateError.DuplicateSlotPolicy
                }
                slots.mapIndexed { index, slot ->
                    (slot.slotId?.let { activeById[it] } ?: existingGoal.newSlotDefaults()).copy(
                        slotType = GoalSlotType.PRAYER,
                        prayerName = slot.prayer,
                        prayerRelation = slot.relation,
                        startLeadMinutesOverride = slot.beforeLeadMinutes
                            ?.takeIf { slot.relation == PrayerRelation.BEFORE },
                        startMinute = null,
                        endMinute = null,
                        label = slot.label?.trim()?.takeIf { it.isNotBlank() }
                            ?: slot.defaultLabel(),
                        sortOrder = index,
                        isActive = true,
                        archivedAt = null,
                    )
                }
            }
            is ScheduleTimingUpdate.TimeWindows -> {
                if (windows.isEmpty()) errors += GoalUpdateError.InvalidTiming
                windows.mapIndexed { index, window ->
                    if (window.label.isBlank() ||
                        window.startMinute !in 0 until MINUTES_PER_DAY ||
                        window.endMinute !in 1..MINUTES_PER_DAY ||
                        window.startMinute >= window.endMinute
                    ) {
                        errors += GoalUpdateError.InvalidTiming
                    }
                    (window.slotId?.let { activeById[it] } ?: existingGoal.newSlotDefaults()).copy(
                        slotType = GoalSlotType.TIME_WINDOW,
                        prayerName = null,
                        prayerRelation = null,
                        startLeadMinutesOverride = null,
                        startMinute = window.startMinute,
                        endMinute = window.endMinute,
                        label = window.label.trim(),
                        sortOrder = index,
                        isActive = true,
                        archivedAt = null,
                    )
                }
            }
        }
    }

    private fun ScheduleTimingUpdate.requestedSlotIds(): List<Long> =
        when (this) {
            is ScheduleTimingUpdate.Anytime -> listOfNotNull(slotId)
            is ScheduleTimingUpdate.PrayerBased -> slots.mapNotNull { it.slotId }
            is ScheduleTimingUpdate.TimeWindows -> windows.mapNotNull { it.slotId }
        }.filter { it > 0 }

    private fun Goal.newSlotDefaults(): GoalSlot {
        val template = slots.maxByOrNull { it.sortOrder }
        val defaultTarget = if (targetPolicy == TargetPolicy.NONE) {
            null
        } else {
            template?.targetCount ?: defaultTargetCount()
        }
        return GoalSlot(
            goalId = id,
            minimumCount = template?.minimumCount ?: minimumStreakCount,
            targetCount = defaultTarget,
            maximumCount = template?.maximumCount ?: maximumCount,
            capBehavior = template?.capBehavior ?: capBehavior,
        )
    }

    private fun Goal.defaultTargetCount(): Int? {
        val singleTarget = slots.singleOrNull()?.targetCount
        if (singleTarget != null) return singleTarget
        return slots.sumOf { it.targetCount ?: 0 }.takeIf { it > 0 }
    }

    private fun List<GoalSlot>.aggregateMinimumCount(defaultMinimum: Int?): Int? {
        if (size <= 1) return firstOrNull()?.minimumCount ?: defaultMinimum
        val slotMinimums = mapNotNull { it.minimumCount }
        return if (slotMinimums.size == size) slotMinimums.sum() else defaultMinimum
    }

    private fun List<GoalSlot>.aggregateMaximumCount(defaultMaximum: Int?): Int? {
        if (size <= 1) return firstOrNull()?.maximumCount ?: defaultMaximum
        val slotMaximums = mapNotNull { it.maximumCount }
        return if (slotMaximums.size == size) slotMaximums.sum() else null
    }

    private fun List<GoalSlot>.aggregateCapBehavior(defaultBehavior: CountCapBehavior): CountCapBehavior {
        if (isEmpty()) return defaultBehavior
        return map { it.capBehavior }.distinct().singleOrNull() ?: CountCapBehavior.AllowOverTarget
    }

    private fun PrayerSlotUpdate.defaultLabel(): String =
        "${relation.displayName()} ${prayer.displayName()}"

    private fun PrayerRelation.displayName(): String = when (this) {
        PrayerRelation.BEFORE -> "Before"
        PrayerRelation.AFTER -> "After"
    }

    private fun Prayer.displayName(): String = name.lowercase().replaceFirstChar { it.uppercase() }

    private const val MINUTES_PER_DAY = 24 * 60
}
