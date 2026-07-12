package app.awrad.awrad_dhikrgoalstracker.notification

import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalReminder
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.PrayerRelation
import app.awrad.awrad_dhikrgoalstracker.data.model.ReminderType
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import app.awrad.awrad_dhikrgoalstracker.util.GoalProgressCalculator
import app.awrad.awrad_dhikrgoalstracker.util.SlotTimingResolver
import com.batoulapps.adhan.PrayerTimes
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import javax.inject.Inject
import javax.inject.Singleton

data class ReminderOccurrence(
    val goalId: Long,
    val reminderId: Long,
    val slotId: Long?,
    val slotLabel: String?,
    val occurrenceDate: LocalDate,
    val triggerAtMillis: Long,
)

@Singleton
class ReminderOccurrenceResolver @Inject constructor() {

    fun resolveNextOccurrences(
        goal: Goal,
        nowMillis: Long,
        prayerTimesForDate: (LocalDate) -> PrayerTimes?,
        zoneId: ZoneId = ZoneId.systemDefault(),
        searchDays: Long = 370,
    ): List<ReminderOccurrence> {
        if (!goal.isActive || goal.isCompleted) return emptyList()

        return goal.reminders
            .filter { it.enabled }
            .flatMap { reminder ->
                candidateSlots(goal, reminder).mapNotNull { slot ->
                    resolveNextOccurrence(
                        goal = goal,
                        reminder = reminder,
                        slot = slot,
                        nowMillis = nowMillis,
                        prayerTimesForDate = prayerTimesForDate,
                        zoneId = zoneId,
                        searchDays = searchDays,
                    )
                }
            }
    }

    private fun resolveNextOccurrence(
        goal: Goal,
        reminder: GoalReminder,
        slot: GoalSlot?,
        nowMillis: Long,
        prayerTimesForDate: (LocalDate) -> PrayerTimes?,
        zoneId: ZoneId,
        searchDays: Long,
    ): ReminderOccurrence? {
        val today = millisToDate(nowMillis, zoneId)
        for (offset in 0..searchDays) {
            val date = today.plusDays(offset)
            if (!GoalProgressCalculator.isDueToday(goal, date)) continue

            val prayerTimes = if (requiresPrayerTimes(reminder)) prayerTimesForDate(date) else null
            val triggerAt = triggerAtMillis(reminder, slot, date, prayerTimes, zoneId) ?: continue
            if (triggerAt <= nowMillis) continue

            return ReminderOccurrence(
                goalId = goal.id,
                reminderId = reminder.id,
                slotId = slot?.id,
                slotLabel = slot?.displayLabel(),
                occurrenceDate = date,
                triggerAtMillis = triggerAt,
            )
        }
        return null
    }

    private fun candidateSlots(goal: Goal, reminder: GoalReminder): List<GoalSlot?> {
        reminder.slotId?.let { slotId ->
            return goal.slots.firstOrNull { it.id == slotId }?.let { listOf(it) }.orEmpty()
        }

        return when (reminder.reminderType) {
            ReminderType.FIXED_TIME -> listOf(null)
            ReminderType.PRAYER_OFFSET -> goal.slots.filter { it.slotType == GoalSlotType.PRAYER }
            ReminderType.TIME_WINDOW_START -> goal.slots.filter { it.slotType == GoalSlotType.TIME_WINDOW }
        }
    }

    private fun triggerAtMillis(
        reminder: GoalReminder,
        slot: GoalSlot?,
        date: LocalDate,
        prayerTimes: PrayerTimes?,
        zoneId: ZoneId,
    ): Long? {
        return when (reminder.reminderType) {
            ReminderType.FIXED_TIME -> {
                val hour = reminder.hour ?: return null
                val minute = reminder.minute ?: return null
                date.atTime(LocalTime.of(hour, minute)).atZone(zoneId).toInstant().toEpochMilli()
            }
            ReminderType.PRAYER_OFFSET -> {
                val prayerSlot = slot?.takeIf { it.slotType == GoalSlotType.PRAYER } ?: return null
                val prayerTime = SlotTimingResolver.prayerTime(prayerSlot.prayerName, prayerTimes) ?: return null
                val offsetMillis = (reminder.offsetMinutes ?: DEFAULT_PRAYER_OFFSET_MINUTES)
                    .coerceAtLeast(0) * MILLIS_PER_MINUTE
                if (prayerSlot.prayerRelation == PrayerRelation.BEFORE) {
                    prayerTime.time - offsetMillis
                } else {
                    prayerTime.time + offsetMillis
                }
            }
            ReminderType.TIME_WINDOW_START -> {
                val timeSlot = slot?.takeIf { it.slotType == GoalSlotType.TIME_WINDOW } ?: return null
                val startMinute = timeSlot.startMinute ?: return null
                val offsetMinutes = reminder.offsetMinutes ?: 0
                date.atStartOfDay()
                    .plusMinutes((startMinute + offsetMinutes).toLong())
                    .atZone(zoneId)
                    .toInstant()
                    .toEpochMilli()
            }
        }
    }

    private fun requiresPrayerTimes(reminder: GoalReminder): Boolean =
        reminder.reminderType == ReminderType.PRAYER_OFFSET

    private fun millisToDate(millis: Long, zoneId: ZoneId): LocalDate =
        java.time.Instant.ofEpochMilli(millis).atZone(zoneId).toLocalDate()

    private fun GoalSlot.displayLabel(): String =
        label ?: timingValue?.replace('_', ' ')?.replaceFirstChar { it.uppercase() } ?: "Slot"

    private companion object {
        private const val DEFAULT_PRAYER_OFFSET_MINUTES = 10
        private const val MILLIS_PER_MINUTE = 60_000L
    }
}

object ReminderDeliveryEvaluator {
    fun isCompleteForReminder(goal: Goal, slot: GoalSlot?, progressCount: Long): Boolean {
        if (goal.targetPolicy == TargetPolicy.NONE) return progressCount > 0
        val target = slot?.targetCount ?: GoalProgressCalculator.getTotalDailyTarget(goal)
        return target > 0 && progressCount >= target
    }
}
