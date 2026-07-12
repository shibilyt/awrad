package app.awrad.awrad_dhikrgoalstracker.data.repository

import app.awrad.awrad_dhikrgoalstracker.data.model.GoalReminder
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.ReminderType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class GoalPersistenceMapperTest {

    @Test
    fun `normalizes reminder slot id to persisted inserted slot id`() {
        val reminder = GoalReminder(slotId = 42, reminderType = ReminderType.TIME_WINDOW_START)
        val slots = listOf(
            GoalSlot(id = 42, goalId = 0, slotType = GoalSlotType.TIME_WINDOW),
        )

        val normalized = GoalPersistenceMapper.normalizedReminderSlotId(
            reminder = reminder,
            slots = slots,
            persistedSlotIds = listOf(105),
        )

        assertEquals(105L, normalized)
    }

    @Test
    fun `normalizes transient reminder slot id by matching transient slot position`() {
        val reminder = GoalReminder(slotId = 0, reminderType = ReminderType.TIME_WINDOW_START)
        val slots = listOf(
            GoalSlot(id = 0, goalId = 0, slotType = GoalSlotType.TIME_WINDOW),
        )

        val normalized = GoalPersistenceMapper.normalizedReminderSlotId(
            reminder = reminder,
            slots = slots,
            persistedSlotIds = listOf(106),
        )

        assertEquals(106L, normalized)
    }

    @Test
    fun `drops reminder slot id when referenced slot is no longer part of goal`() {
        val reminder = GoalReminder(slotId = 42, reminderType = ReminderType.TIME_WINDOW_START)
        val slots = listOf(
            GoalSlot(id = 7, goalId = 1, slotType = GoalSlotType.ANYTIME),
        )

        val normalized = GoalPersistenceMapper.normalizedReminderSlotId(
            reminder = reminder,
            slots = slots,
            persistedSlotIds = listOf(7),
        )

        assertNull(normalized)
    }

    @Test
    fun `maps reminder entity with persisted goal and slot ids`() {
        val entity = GoalPersistenceMapper.toEntity(
            reminder = GoalReminder(
                id = 3,
                goalId = 1,
                slotId = 2,
                reminderType = ReminderType.FIXED_TIME,
                hour = 5,
                minute = 30,
                enabled = true,
                sortOrder = 4,
            ),
            goalId = 9,
            slotId = 11,
        )

        assertEquals(3L, entity.id)
        assertEquals(9L, entity.goalId)
        assertEquals(11L, entity.slotId)
        assertEquals(ReminderType.FIXED_TIME, entity.reminderType)
        assertEquals(5, entity.hour)
        assertEquals(30, entity.minute)
        assertEquals(4, entity.sortOrder)
    }
}
