package app.awrad.awrad_dhikrgoalstracker.ui.screens.wird

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WirdDetailSurfaceTest {

    @Test
    fun `detail surface removes redundant summary metrics`() {
        val source = screenSource().readText()

        assertFalse("The detail screen should no longer render the metric row", "StatRow(" in source)
        assertFalse("The detail screen should not expose a duration metric", "wird_stat_to_recite" in source)
        assertFalse("The detail screen should not expose a streak metric", "wird_stat_day_streak" in source)
        assertFalse("The detail screen should not repeat the total recitation count", "wird_recitations_count" in source)
        assertTrue("The reading plan should invite section selection", "wird_choose_section" in source)
    }

    @Test
    fun `hero keeps identity and progress while the page adds a visible reminder card`() {
        val source = screenSource().readText()

        assertTrue("The hero should keep the Arabic wird identity", "WirdHeroCard(" in source)
        assertTrue("The hero should retain today's progress ring", "CircularProgressIndicator(" in source)
        assertTrue("The page should show reminder state without opening the menu", "ReminderCard(" in source)
        assertTrue("Reminder changes should remain owned by the ViewModel", "viewModel.setReminderEnabled" in source)
    }

    @Test
    fun `section rows stay actionable and preserve reader navigation`() {
        val source = screenSource().readText()

        assertTrue("Section rows should remain clickable", "PartCard(" in source)
        assertTrue("Section rows should navigate to the reader", "onNavigateToReader(wird.id, row.part.id)" in source)
        assertTrue("The sticky reader action should remain available", "BeginRecitationBar(" in source)
    }

    private fun screenSource(): File {
        val relativePath =
            "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/wird/WirdDetailScreen.kt"
        val workingDirectory = requireNotNull(System.getProperty("user.dir"))
        return generateSequence(File(workingDirectory)) { it.parentFile }
            .flatMap { directory ->
                sequenceOf(
                    directory.resolve(relativePath),
                    directory.resolve("awrad-android/$relativePath"),
                )
            }
            .firstOrNull(File::isFile)
            ?: error("Could not locate $relativePath from $workingDirectory")
    }
}
