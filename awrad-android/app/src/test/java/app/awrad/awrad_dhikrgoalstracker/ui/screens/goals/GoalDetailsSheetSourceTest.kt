package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GoalDetailsSheetSourceTest {
    private fun detailsSheetSource(): String = sourceFile("GoalsScreen.kt").readText()
        .substringAfter("internal fun GoalDetailsBottomSheet(")
        .substringBefore("@Composable\ninternal fun goalTag(")

    @Test
    fun `overflow opens a full height goal details sheet instead of a dropdown`() {
        val source = sourceFile("GoalsScreen.kt").readText()
        val goalCard = source
            .substringAfter("private fun GoalListItem(")
            .substringBefore("internal fun GoalDetailsBottomSheet(")
        val detailsSheet = detailsSheetSource()

        assertTrue("The overflow action must open goal details", "onShowDetails()" in goalCard)
        assertFalse("The overflow action must not open the old dropdown", "DropdownMenu(" in goalCard)
        assertTrue("Goal details must use a modal bottom sheet", "ModalBottomSheet(" in detailsSheet)
        assertTrue("The sheet must skip the partial state", "skipPartiallyExpanded = true" in detailsSheet)
        assertTrue("The goal details sheet must fill the available height", ".fillMaxHeight()" in detailsSheet)
    }

    @Test
    fun `goal details content stays below the status bar`() {
        val detailsSheet = detailsSheetSource()

        assertTrue(
            "The full-height sheet must inset its content below the status bar",
            ".statusBarsPadding()" in detailsSheet,
        )
    }

    @Test
    fun `goal details sheet surface is status safe and shows a drag handle`() {
        val detailsSheet = detailsSheetSource()
        val sheetCall = detailsSheet.substringAfter("ModalBottomSheet(").substringBefore(") {")

        assertTrue(
            "The sheet surface must apply the status-bar inset",
            "modifier = Modifier.statusBarsPadding()" in sheetCall,
        )
        assertTrue(
            "The sheet must expose a drag handle",
            "dragHandle = { BottomSheetDefaults.DragHandle() }" in sheetCall,
        )
    }

    @Test
    fun `goal details sheet keeps the statement and editable details without progress data`() {
        val detailsSheet = detailsSheetSource()

        assertFalse(
            "The statement must not repeat a redundant heading",
            "R.string.goal_sheet_statement_label" in detailsSheet,
        )
        assertTrue("The sheet must render the goal statement", "R.string.goal_sheet_statement" in detailsSheet)
        assertTrue("The sheet must keep editable goal details", "DetailsDisclosure(" in detailsSheet)
        assertFalse("The sheet must not render quick stats", "GoalQuickStat(" in detailsSheet)
        assertFalse("The sheet must not render quick-stat labels", "R.string.goal_sheet_quick_stats" in detailsSheet)
        assertFalse("The sheet must not render a streak calendar", "StreakSection(" in detailsSheet)
        assertFalse("The sheet must not render session data", "SessionsSection(" in detailsSheet)
        assertFalse("The sheet must not receive streak data", "streakInfo:" in detailsSheet)
        assertFalse("The sheet must not receive session count data", "slotCountsToday:" in detailsSheet)
        assertFalse("The sheet must not receive all-time session data", "slotCountsAllTime:" in detailsSheet)
    }

    @Test
    fun `sheet offers archive restore and confirmed delete actions`() {
        val detailsSheet = detailsSheetSource()
        val viewModel = sourceFile("GoalsViewModel.kt").readText()

        assertTrue("The sheet must offer Archive", "R.string.action_archive" in detailsSheet)
        assertTrue("The sheet must offer Restore", "R.string.action_restore" in detailsSheet)
        assertTrue("The sheet must offer Delete", "R.string.action_delete" in detailsSheet)
        assertTrue("Delete must require confirmation", "AlertDialog(" in detailsSheet)
        assertTrue(
            "Archive must use the validated lifecycle transition",
            "GoalLifecycleUpdateFactory.archive(goal)" in viewModel,
        )
        assertTrue(
            "Restore must use the validated lifecycle transition",
            "GoalLifecycleUpdateFactory.restore(goal)" in viewModel,
        )
        assertTrue(
            "Lifecycle changes must use the repository path that preserves archive state",
            "goalRepository.updateGoalLifecycle(update)" in viewModel,
        )
        assertTrue("Archive must cancel scheduled reminders", "scheduler.cancelForGoal(" in viewModel)
        assertTrue("Restore must reschedule reminders", "scheduler.scheduleForGoal(" in viewModel)
    }

    private fun sourceFile(name: String): File {
        val relativePath =
            "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/$name"
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
