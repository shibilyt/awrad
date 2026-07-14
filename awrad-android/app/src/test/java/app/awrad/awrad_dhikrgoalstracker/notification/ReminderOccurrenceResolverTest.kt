package app.awrad.awrad_dhikrgoalstracker.notification

import app.awrad.awrad_dhikrgoalstracker.testId

import app.awrad.awrad_dhikrgoalstracker.data.model.CalendarSystem
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalRecurrence
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalReminder
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSpecificDate
import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.PrayerRelation
import app.awrad.awrad_dhikrgoalstracker.data.model.RecurrenceFrequency
import app.awrad.awrad_dhikrgoalstracker.data.model.ReminderType
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import com.batoulapps.adhan.CalculationMethod
import com.batoulapps.adhan.Coordinates
import com.batoulapps.adhan.Madhab
import com.batoulapps.adhan.PrayerTimes
import com.batoulapps.adhan.data.DateComponents
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId

class ReminderOccurrenceResolverTest {
    private val resolver = ReminderOccurrenceResolver()
    private val zoneId: ZoneId = ZoneId.systemDefault()

    @Test
    fun `weekly prayer slot schedules next friday prayer reminder`() {
        val friday = LocalDate.parse("2026-05-29")
        val slot = dhuhrSlot()
        val goal = goal(
            recurrence = GoalRecurrence(goalId = testId(1),
                frequency = RecurrenceFrequency.WEEKLY,
                weekdays = setOf(DayOfWeek.FRIDAY),
            ),
            slots = listOf(slot),
            reminders = listOf(GoalReminder(id = testId(20), goalId = testId(1), reminderType = ReminderType.PRAYER_OFFSET, offsetMinutes = 10)),
        )
        val now = LocalDate.parse("2026-05-27").atStartOfDay(zoneId).toInstant().toEpochMilli()

        val occurrences = resolver.resolveNextOccurrences(goal, now, ::prayerTimes, zoneId)

        assertEquals(1, occurrences.size)
        assertEquals(friday, occurrences.single().occurrenceDate)
        assertEquals(slot.id, occurrences.single().slotId)
    }

    @Test
    fun `fixed reminder skips non due days`() {
        val goal = goal(
            recurrence = GoalRecurrence(goalId = testId(1),
                frequency = RecurrenceFrequency.WEEKLY,
                weekdays = setOf(DayOfWeek.FRIDAY),
            ),
            reminders = listOf(GoalReminder(id = testId(21), goalId = testId(1), reminderType = ReminderType.FIXED_TIME, hour = 8, minute = 0)),
        )
        val now = LocalDate.parse("2026-05-27").atStartOfDay(zoneId).toInstant().toEpochMilli()

        val occurrence = resolver.resolveNextOccurrences(goal, now, ::prayerTimes, zoneId).single()

        assertEquals(LocalDate.parse("2026-05-29"), occurrence.occurrenceDate)
    }

    @Test
    fun `time window reminder fires at window start`() {
        val date = LocalDate.parse("2026-05-27")
        val slot = GoalSlot(
            id = testId(11),
            goalId = testId(1),
            slotType = GoalSlotType.TIME_WINDOW,
            startMinute = 9 * 60,
            endMinute = 10 * 60,
            targetCount = 100,
        )
        val goal = goal(
            slots = listOf(slot),
            reminders = listOf(GoalReminder(id = testId(22), goalId = testId(1), reminderType = ReminderType.TIME_WINDOW_START)),
        )
        val now = date.atTime(LocalTime.of(8, 0)).atZone(zoneId).toInstant().toEpochMilli()

        val occurrence = resolver.resolveNextOccurrences(goal, now, ::prayerTimes, zoneId).single()

        assertEquals(date, occurrence.occurrenceDate)
        assertEquals(date.atTime(LocalTime.of(9, 0)).atZone(zoneId).toInstant().toEpochMilli(), occurrence.triggerAtMillis)
    }

    @Test
    fun `specific date reminder schedules only the selected date`() {
        val selectedDate = LocalDate.parse("2026-06-01")
        val goal = goal(
            recurrence = GoalRecurrence(goalId = testId(1),
                frequency = RecurrenceFrequency.SPECIFIC_DATES,
                specificDates = setOf(GoalSpecificDate(date = selectedDate, calendar = CalendarSystem.GREGORIAN)),
            ),
            reminders = listOf(GoalReminder(id = testId(23), goalId = testId(1), reminderType = ReminderType.FIXED_TIME, hour = 8, minute = 0)),
        )
        val now = LocalDate.parse("2026-05-27").atStartOfDay(zoneId).toInstant().toEpochMilli()

        val occurrence = resolver.resolveNextOccurrences(goal, now, ::prayerTimes, zoneId).single()

        assertEquals(selectedDate, occurrence.occurrenceDate)
    }

    @Test
    fun `disabled reminders are ignored`() {
        val goal = goal(
            reminders = listOf(
                GoalReminder(
                    id = testId(24),
                    goalId = testId(1),
                    reminderType = ReminderType.FIXED_TIME,
                    hour = 8,
                    minute = 0,
                    enabled = false,
                )
            ),
        )
        val now = LocalDate.parse("2026-05-27").atStartOfDay(zoneId).toInstant().toEpochMilli()

        val occurrences = resolver.resolveNextOccurrences(goal, now, ::prayerTimes, zoneId)

        assertTrue(occurrences.isEmpty())
    }

    @Test
    fun `completed slot suppresses delivery`() {
        val slot = dhuhrSlot(target = 100)
        val goal = goal(slots = listOf(slot))

        assertFalse(ReminderDeliveryEvaluator.isCompleteForReminder(goal, slot, 99))
        assertTrue(ReminderDeliveryEvaluator.isCompleteForReminder(goal, slot, 100))
    }

    private fun goal(
        recurrence: GoalRecurrence = GoalRecurrence(goalId = testId(1), ),
        slots: List<GoalSlot> = listOf(GoalSlot(id = testId(1), goalId = testId(1), slotType = GoalSlotType.ANYTIME, targetCount = 100)),
        reminders: List<GoalReminder> = emptyList(),
    ): Goal = Goal(
        id = testId(1),
        dhikrId = testId(1),
        targetPolicy = TargetPolicy.PER_DUE_DATE,
        recurrence = recurrence,
        slots = slots,
        reminders = reminders,
        startDate = LocalDate.parse("2026-05-24"),
    )

    private fun dhuhrSlot(target: Int = 100): GoalSlot = GoalSlot(
        id = testId(10),
        goalId = testId(1),
        slotType = GoalSlotType.PRAYER,
        prayerName = Prayer.DHUHR,
        prayerRelation = PrayerRelation.AFTER,
        targetCount = target,
        label = "After Dhuhr",
    )

    private fun prayerTimes(date: LocalDate): PrayerTimes {
        val params = CalculationMethod.KARACHI.parameters
        params.madhab = Madhab.SHAFI
        return PrayerTimes(
            Coordinates(10.0, 76.0),
            DateComponents(date.year, date.monthValue, date.dayOfMonth),
            params,
        )
    }
}
