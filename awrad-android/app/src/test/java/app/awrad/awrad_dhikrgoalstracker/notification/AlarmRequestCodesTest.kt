package app.awrad.awrad_dhikrgoalstracker.notification

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
            id = 42,
            dhikrId = 7,
            startDate = LocalDate.parse("2026-06-01"),
            slots = listOf(
                GoalSlot(
                    id = 12,
                    goalId = 42,
                    slotType = GoalSlotType.TIME_WINDOW,
                    startMinute = 8 * 60,
                    endMinute = 9 * 60,
                ),
            ),
            reminders = listOf(
                GoalReminder(
                    id = 5,
                    goalId = 42,
                    reminderType = ReminderType.FIXED_TIME,
                    hour = 8,
                    minute = 0,
                ),
                GoalReminder(
                    id = 6,
                    goalId = 42,
                    slotId = 12,
                    reminderType = ReminderType.TIME_WINDOW_START,
                ),
            ),
        )

        val codes = AlarmRequestCodes.codesToCancelBeforeReschedule(listOf(goal))

        assertTrue(codes.contains(AlarmRequestCodes.GLOBAL))
        assertTrue(codes.contains(AlarmRequestCodes.goalReminder(42)))
        assertTrue(codes.contains(AlarmRequestCodes.prayerSlot(42, 0)))
        assertTrue(codes.contains(AlarmRequestCodes.prayerSlot(42, 9)))
        assertTrue(codes.contains(AlarmRequestCodes.goalFollowUp(42)))
        assertTrue(codes.contains(AlarmRequestCodes.goalFollowUp(42, 12)))
        assertTrue(codes.contains(AlarmRequestCodes.reminder(42, 5, null)))
        assertTrue(codes.contains(AlarmRequestCodes.reminder(42, 5, 12)))
        assertTrue(codes.contains(AlarmRequestCodes.reminder(42, 6, 12)))
    }
}
