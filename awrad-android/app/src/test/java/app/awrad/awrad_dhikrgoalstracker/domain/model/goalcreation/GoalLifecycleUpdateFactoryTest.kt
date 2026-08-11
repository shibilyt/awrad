package app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation

import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.testId
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class GoalLifecycleUpdateFactoryTest {
    @Test
    fun `archive deactivates an unfinished goal without losing progress`() {
        val goal = goal(totalCompletedCount = 72L)

        val update = GoalLifecycleUpdateFactory.archive(goal, updatedAtMillis = 2_000L)
        assertNotNull(update)
        update!!

        assertFalse(update.goal.isActive)
        assertNull(update.goal.completedAt)
        assertEquals(72L, update.goal.totalCompletedCount)
        assertEquals(goal.createdAt, update.goal.createdAt)
        assertEquals(2_000L, update.goal.updatedAt)
    }

    @Test
    fun `restore reactivates only an archived goal without losing progress`() {
        val archived = goal(
            isActive = false,
            completedAt = null,
            totalCompletedCount = 72L,
        )

        val update = GoalLifecycleUpdateFactory.restore(archived, updatedAtMillis = 3_000L)
        assertNotNull(update)
        update!!

        assertTrue(update.goal.isActive)
        assertNull(update.goal.completedAt)
        assertEquals(72L, update.goal.totalCompletedCount)
        assertEquals(3_000L, update.goal.updatedAt)
    }

    @Test
    fun `archive and restore reject invalid lifecycle transitions`() {
        val active = goal()
        val archived = goal(isActive = false)
        val completed = goal(isActive = false, completedAt = 1_500L)

        assertNull(GoalLifecycleUpdateFactory.archive(archived, updatedAtMillis = 2_000L))
        assertNull(GoalLifecycleUpdateFactory.archive(completed, updatedAtMillis = 2_000L))
        assertNull(GoalLifecycleUpdateFactory.restore(active, updatedAtMillis = 2_000L))
        assertNull(GoalLifecycleUpdateFactory.restore(completed, updatedAtMillis = 2_000L))
    }

    private fun goal(
        isActive: Boolean = true,
        completedAt: Long? = null,
        totalCompletedCount: Long = 0L,
    ) = Goal(
        id = testId(1),
        dhikrId = testId(2),
        startDate = LocalDate.of(2026, 8, 7),
        totalCompletedCount = totalCompletedCount,
        isActive = isActive,
        completedAt = completedAt,
        createdAt = 1_000L,
        updatedAt = 1_000L,
    )
}
