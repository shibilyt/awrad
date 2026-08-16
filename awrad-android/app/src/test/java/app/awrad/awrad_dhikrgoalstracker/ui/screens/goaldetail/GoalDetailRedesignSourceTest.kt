package app.awrad.awrad_dhikrgoalstracker.ui.screens.goaldetail

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GoalDetailRedesignSourceTest {
    @Test
    fun `detail screen leads with progress instead of configuration`() {
        val source = sourceFile("GoalDetailScreen.kt").readText()

        assertTrue("The screen must show the streak chip", "GoalStreakChip(" in source)
        assertTrue("The screen must render the last 7 days strip", "GoalStreakStrip(" in source)
        assertTrue("The screen must render the quick stats row", "StatsRow(" in source)
        assertTrue("The screen must label the 7 day strip", "R.string.goal_details_last_7_days" in source)
        assertTrue("The hero must show the goal tag", "goalTag(goal)" in source)
        assertTrue("The hero must show the schedule tag", "goalScheduleTag(goal)" in source)
        assertTrue(
            "Configuration must be folded into a Details disclosure",
            "DetailsDisclosure(" in source,
        )
        assertFalse("The old overview section must be gone", "GoalOverviewSection(" in source)
        assertFalse("The old top-level reminders section must be gone", "RemindersSection(" in source)
        assertFalse("The monthly grid is out of scope for this screen", "StreakSection(" in source)
    }

    @Test
    fun `top bar offers overflow with lifecycle actions and confirmed delete`() {
        val source = sourceFile("GoalDetailScreen.kt").readText()
        val topBar = source.substringAfter("private fun GoalDetailTopBar(")
            .substringBefore("private fun GoalHeroCard(")

        assertTrue("The top bar must expose an actions slot", "actions: @Composable RowScope.() -> Unit = {}" in topBar)
        assertTrue("The back action must keep the shared circular treatment", "FilledIconButton(" in topBar)
        assertTrue(
            "The back circle must keep the muted surface token",
            "containerColor = MaterialTheme.colorScheme.surfaceContainerHighest" in topBar,
        )

        assertTrue("The overflow must use the more-options icon", "Icons.Default.MoreVert" in source)
        assertTrue("The overflow must read the shared content description", "R.string.cd_more_options" in source)
        assertTrue("The overflow must be a dropdown", "DropdownMenu(" in source)
        assertTrue("Delete must require confirmation", "AlertDialog(" in source)
        assertTrue("The menu must offer Archive", "R.string.action_archive" in source)
        assertTrue("The menu must offer Restore", "R.string.action_restore" in source)
        assertTrue("The menu must offer Delete", "R.string.action_delete" in source)
    }

    @Test
    fun `view model drives lifecycle through the repository and scheduler`() {
        val viewModel = sourceFile("GoalDetailViewModel.kt").readText()

        assertTrue(
            "Archive must use the validated lifecycle transition",
            "GoalLifecycleUpdateFactory.archive(goal)" in viewModel,
        )
        assertTrue(
            "Restore must use the validated lifecycle transition",
            "GoalLifecycleUpdateFactory.restore(goal)" in viewModel,
        )
        assertTrue(
            "Lifecycle changes must go through the repository",
            "goalRepository.updateGoalLifecycle(update)" in viewModel,
        )
        assertTrue("Delete must remove the goal", "goalRepository.deleteGoal(goalId)" in viewModel)
        assertTrue("Archive must cancel scheduled reminders", "scheduler.cancelForGoal(" in viewModel)
        assertTrue("Restore must reschedule reminders", "scheduler.scheduleForGoal(" in viewModel)
    }

    private fun sourceFile(name: String): File {
        val relativePath =
            "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goaldetail/$name"
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
