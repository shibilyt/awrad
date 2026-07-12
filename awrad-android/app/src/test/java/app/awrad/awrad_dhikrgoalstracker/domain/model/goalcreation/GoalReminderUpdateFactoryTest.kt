package app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation

import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalReminder
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.PrayerRelation
import app.awrad.awrad_dhikrgoalstracker.data.model.ReminderType
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GoalReminderUpdateFactoryTest {

    @Test
    fun `empty reminder list is valid and turns reminders off`() {
        val update = validUpdate(command = command(reminders = emptyList()))

        assertTrue(update.goal.reminders.isEmpty())
    }

    @Test
    fun `valid reminders are normalized in draft order`() {
        val update = validUpdate(
            command = command(
                reminders = listOf(
                    GoalReminderUpdate(
                        reminderId = 1,
                        reminderType = ReminderType.FIXED_TIME,
                        hour = 7,
                        minute = 30,
                        enabled = false,
                    ),
                    GoalReminderUpdate(
                        reminderType = ReminderType.PRAYER_OFFSET,
                        slotId = 11,
                        offsetMinutes = null,
                    ),
                    GoalReminderUpdate(
                        reminderType = ReminderType.TIME_WINDOW_START,
                        slotId = null,
                        offsetMinutes = 99,
                    ),
                )
            ),
        )

        assertEquals(listOf(0, 1, 2), update.goal.reminders.map { it.sortOrder })
        assertFalse(update.goal.reminders[0].enabled)
        assertEquals(10, update.goal.reminders[1].offsetMinutes)
        assertEquals(0, update.goal.reminders[2].offsetMinutes)
    }

    @Test
    fun `fixed time validates hour and minute`() {
        listOf(
            GoalReminderUpdate(reminderType = ReminderType.FIXED_TIME, hour = -1, minute = 0),
            GoalReminderUpdate(reminderType = ReminderType.FIXED_TIME, hour = 24, minute = 0),
            GoalReminderUpdate(reminderType = ReminderType.FIXED_TIME, hour = 6, minute = -1),
            GoalReminderUpdate(reminderType = ReminderType.FIXED_TIME, hour = 6, minute = 60),
            GoalReminderUpdate(reminderType = ReminderType.FIXED_TIME, slotId = 10, hour = 6, minute = 0),
        ).forEach { reminder ->
            val result = GoalReminderUpdateFactory.update(goal(), command(reminders = listOf(reminder)))

            assertTrue(result is GoalUpdateResult.Invalid)
            assertTrue((result as GoalUpdateResult.Invalid).errors.contains(GoalUpdateError.InvalidReminder))
        }
    }

    @Test
    fun `slot reminders require active matching slots`() {
        listOf(
            GoalReminderUpdate(reminderType = ReminderType.PRAYER_OFFSET, slotId = 10, offsetMinutes = 10),
            GoalReminderUpdate(reminderType = ReminderType.PRAYER_OFFSET, slotId = 99, offsetMinutes = 10),
            GoalReminderUpdate(reminderType = ReminderType.TIME_WINDOW_START, slotId = 11),
            GoalReminderUpdate(reminderType = ReminderType.TIME_WINDOW_START, slotId = 99),
        ).forEach { reminder ->
            val result = GoalReminderUpdateFactory.update(goal(), command(reminders = listOf(reminder)))

            assertTrue(result is GoalUpdateResult.Invalid)
            assertTrue((result as GoalUpdateResult.Invalid).errors.contains(GoalUpdateError.InvalidReminder))
        }
    }

    @Test
    fun `archived slot targets are rejected`() {
        val result = GoalReminderUpdateFactory.update(
            goal(
                archivedSlots = listOf(
                    slot(id = 20, slotType = GoalSlotType.TIME_WINDOW, isActive = false),
                )
            ),
            command(
                reminders = listOf(
                    GoalReminderUpdate(reminderType = ReminderType.TIME_WINDOW_START, slotId = 20)
                )
            ),
        )

        assertTrue(result is GoalUpdateResult.Invalid)
        assertTrue((result as GoalUpdateResult.Invalid).errors.contains(GoalUpdateError.InvalidReminder))
    }

    @Test
    fun `unavailable aggregate slot reminder types are rejected`() {
        val noPrayer = GoalReminderUpdateFactory.update(
            goal(slots = listOf(slot(id = 10, slotType = GoalSlotType.TIME_WINDOW))),
            command(reminders = listOf(GoalReminderUpdate(reminderType = ReminderType.PRAYER_OFFSET))),
        )
        val noTimeWindow = GoalReminderUpdateFactory.update(
            goal(slots = listOf(slot(id = 11, slotType = GoalSlotType.PRAYER))),
            command(reminders = listOf(GoalReminderUpdate(reminderType = ReminderType.TIME_WINDOW_START))),
        )

        assertTrue(noPrayer is GoalUpdateResult.Invalid)
        assertTrue((noPrayer as GoalUpdateResult.Invalid).errors.contains(GoalUpdateError.InvalidReminder))
        assertTrue(noTimeWindow is GoalUpdateResult.Invalid)
        assertTrue((noTimeWindow as GoalUpdateResult.Invalid).errors.contains(GoalUpdateError.InvalidReminder))
    }

    @Test
    fun `duplicates are rejected by type target time and offset`() {
        val result = GoalReminderUpdateFactory.update(
            goal(),
            command(
                reminders = listOf(
                    GoalReminderUpdate(reminderType = ReminderType.FIXED_TIME, hour = 6, minute = 0),
                    GoalReminderUpdate(reminderType = ReminderType.FIXED_TIME, hour = 6, minute = 0),
                )
            ),
        )

        assertTrue(result is GoalUpdateResult.Invalid)
        assertTrue((result as GoalUpdateResult.Invalid).errors.contains(GoalUpdateError.DuplicateReminder))
    }

    @Test
    fun `unknown existing reminder id is rejected`() {
        val result = GoalReminderUpdateFactory.update(
            goal(),
            command(
                reminders = listOf(
                    GoalReminderUpdate(reminderId = 99, reminderType = ReminderType.FIXED_TIME, hour = 6, minute = 0)
                )
            ),
        )

        assertTrue(result is GoalUpdateResult.Invalid)
        assertTrue((result as GoalUpdateResult.Invalid).errors.contains(GoalUpdateError.InvalidReminder))
    }

    private fun validUpdate(
        existingGoal: Goal = goal(),
        command: UpdateGoalRemindersCommand,
    ): ValidatedGoalUpdate =
        (GoalReminderUpdateFactory.update(existingGoal, command) as GoalUpdateResult.Valid).validatedGoalUpdate

    private fun command(reminders: List<GoalReminderUpdate>) =
        UpdateGoalRemindersCommand(goalId = 1, reminders = reminders)

    private fun goal(
        slots: List<GoalSlot> = listOf(
            slot(id = 10, slotType = GoalSlotType.TIME_WINDOW),
            slot(id = 11, slotType = GoalSlotType.PRAYER),
        ),
        archivedSlots: List<GoalSlot> = emptyList(),
        reminders: List<GoalReminder> = listOf(
            GoalReminder(id = 1, goalId = 1, reminderType = ReminderType.FIXED_TIME, hour = 8, minute = 0)
        ),
    ) = Goal(
        id = 1,
        dhikrId = 1,
        slots = slots,
        archivedSlots = archivedSlots,
        reminders = reminders,
        startDate = LocalDate.parse("2026-05-27"),
    )

    private fun slot(
        id: Long,
        slotType: GoalSlotType,
        isActive: Boolean = true,
    ) = GoalSlot(
        id = id,
        goalId = 1,
        slotType = slotType,
        prayerName = if (slotType == GoalSlotType.PRAYER) Prayer.FAJR else null,
        prayerRelation = if (slotType == GoalSlotType.PRAYER) PrayerRelation.AFTER else null,
        startMinute = if (slotType == GoalSlotType.TIME_WINDOW) 6 * 60 else null,
        endMinute = if (slotType == GoalSlotType.TIME_WINDOW) 9 * 60 else null,
        label = "Session",
        isActive = isActive,
        archivedAt = if (isActive) null else 1234L,
    )
}
