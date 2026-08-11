package app.awrad.awrad_dhikrgoalstracker.data.repository

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GoalLifecycleRepositorySourceTest {
    @Test
    fun `lifecycle updates persist the requested state without recomputing completion`() {
        val repository = sourceFile("GoalRepositoryImpl.kt").readText()
        val lifecycleUpdate = repository
            .substringAfter("override suspend fun updateGoalLifecycle(")
            .substringBefore("override suspend fun updateGoalSchedule(")

        assertTrue("Lifecycle updates must persist the goal aggregate", "updateGoalAggregate(goal)" in lifecycleUpdate)
        assertTrue("Lifecycle updates must return the stored goal", "getGoalById(goal.id)" in lifecycleUpdate)
        assertFalse(
            "Archiving must not auto-complete a target-reached cumulative goal",
            "recomputeCompletionAfterCountSetupUpdate" in lifecycleUpdate,
        )
        assertTrue(
            "Lifecycle updates must refresh notification obligations",
            "NotificationObligationRequestReason.GOAL_MUTATION" in lifecycleUpdate,
        )
    }

    private fun sourceFile(name: String): File {
        val relativePath =
            "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/data/repository/$name"
        val workingDirectory = requireNotNull(System.getProperty("user.dir"))
        return generateSequence(File(workingDirectory)) { it.parentFile }
            .flatMap { directory ->
                sequenceOf(
                    directory.resolve(relativePath),
                    directory.resolve("awrad-android/$relativePath"),
                )
            }
            .firstOrNull(File::isFile)
            ?: error("Could not locate $name from $workingDirectory")
    }
}
