package app.awrad.awrad_dhikrgoalstracker.notification

import app.awrad.awrad_dhikrgoalstracker.testId

import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalReminder
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.ReminderType
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class AlarmRequestCodesTest {

    @Test
    fun `codes to cancel before reschedule include global legacy followup and reminder codes`() {
        val goal = Goal(
            id = testId(42),
            dhikrId = testId(7),
            startDate = LocalDate.parse("2026-06-01"),
            slots = listOf(
                GoalSlot(
                    id = testId(12),
                    goalId = testId(42),
                    slotType = GoalSlotType.TIME_WINDOW,
                    startMinute = 8 * 60,
                    endMinute = 9 * 60,
                ),
            ),
            reminders = listOf(
                GoalReminder(
                    id = testId(5),
                    goalId = testId(42),
                    reminderType = ReminderType.FIXED_TIME,
                    hour = 8,
                    minute = 0,
                ),
                GoalReminder(
                    id = testId(6),
                    goalId = testId(42),
                    slotId = testId(12),
                    reminderType = ReminderType.TIME_WINDOW_START,
                ),
            ),
        )

        val codes = AlarmRequestCodes.codesToCancelBeforeReschedule(listOf(goal))

        assertTrue(codes.contains(AlarmRequestCodes.GLOBAL))
        assertTrue(codes.contains(AlarmRequestCodes.goalReminder(testId(42))))
        assertTrue(codes.contains(AlarmRequestCodes.prayerSlot(testId(42), 0)))
        assertTrue(codes.contains(AlarmRequestCodes.prayerSlot(testId(42), 9)))
        assertTrue(codes.contains(AlarmRequestCodes.goalFollowUp(testId(42))))
        assertTrue(codes.contains(AlarmRequestCodes.goalFollowUp(testId(42), testId(12))))
        assertTrue(codes.contains(AlarmRequestCodes.reminder(testId(42), testId(5), null)))
        assertTrue(codes.contains(AlarmRequestCodes.reminder(testId(42), testId(5), testId(12))))
        assertTrue(codes.contains(AlarmRequestCodes.reminder(testId(42), testId(6), testId(12))))
    }
}
