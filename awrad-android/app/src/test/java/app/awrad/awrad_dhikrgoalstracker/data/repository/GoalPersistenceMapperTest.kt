package app.awrad.awrad_dhikrgoalstracker.data.repository

import app.awrad.awrad_dhikrgoalstracker.data.model.GoalReminder
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.ReminderType
import app.awrad.awrad_dhikrgoalstracker.testId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class GoalPersistenceMapperTest {
    @Test
    fun `keeps preassigned reminder slot id when slot belongs to aggregate`() {
        val slotID = testId(42)
        val reminder = GoalReminder(goalId = testId(1), slotId = slotID)
        val slots = listOf(GoalSlot(id = slotID, goalId = testId(1), slotType = GoalSlotType.TIME_WINDOW))

        assertEquals(slotID, GoalPersistenceMapper.normalizedReminderSlotId(reminder, slots))
    }

    @Test
    fun `drops reminder slot id when referenced slot is not in aggregate`() {
        val reminder = GoalReminder(goalId = testId(1), slotId = testId(42))
        val slots = listOf(GoalSlot(id = testId(7), goalId = testId(1)))

        assertNull(GoalPersistenceMapper.normalizedReminderSlotId(reminder, slots))
    }

    @Test
    fun `maps preassigned reminder UUIDs without post insert remapping`() {
        val entity = GoalPersistenceMapper.toEntity(
            reminder = GoalReminder(
                id = testId(3),
                goalId = testId(1),
                slotId = testId(2),
                reminderType = ReminderType.FIXED_TIME,
                hour = 5,
                minute = 30,
                sortOrder = 4,
            ),
            goalId = testId(9),
            slotId = testId(11),
        )

        assertEquals(testId(3), entity.id)
        assertEquals(testId(9), entity.goalId)
        assertEquals(testId(11), entity.slotId)
        assertEquals(4, entity.sortOrder)
    }
}
