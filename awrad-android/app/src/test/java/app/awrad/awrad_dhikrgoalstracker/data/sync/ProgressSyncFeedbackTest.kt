package app.awrad.awrad_dhikrgoalstracker.data.sync

import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class ProgressSyncFeedbackTest {
    @Test
    fun `aggregates remote count changes by goal`() {
        val firstGoal = UUID.randomUUID()
        val secondGoal = UUID.randomUUID()

        val result = aggregateRemoteCountChanges(
            listOf(
                ProgressSyncCountChange(firstGoal, 8),
                ProgressSyncCountChange(secondGoal, 4),
                ProgressSyncCountChange(firstGoal, 3),
            ),
        )

        assertEquals(11L, result[firstGoal])
        assertEquals(4L, result[secondGoal])
    }

    @Test
    fun `drops a goal whose synced adjustments cancel out`() {
        val goalId = UUID.randomUUID()

        val result = aggregateRemoteCountChanges(
            listOf(
                ProgressSyncCountChange(goalId, 5),
                ProgressSyncCountChange(goalId, -5),
            ),
        )

        assertFalse(result.containsKey(goalId))
    }

    @Test
    fun `saturates an overflowing aggregate so feedback cannot fail sync`() {
        val goalId = UUID.randomUUID()

        val result = aggregateRemoteCountChanges(
            listOf(
                ProgressSyncCountChange(goalId, Long.MAX_VALUE),
                ProgressSyncCountChange(goalId, 1),
            ),
        )

        assertEquals(Long.MAX_VALUE, result[goalId])
    }
}
