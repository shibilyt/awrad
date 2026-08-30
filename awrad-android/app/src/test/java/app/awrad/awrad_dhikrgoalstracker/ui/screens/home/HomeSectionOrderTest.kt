package app.awrad.awrad_dhikrgoalstracker.ui.screens.home

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HomeSectionOrderTest {
    @Test
    fun `home no longer renders the continue goal card`() {
        val screen = homeScreenSource()
            .substringAfter("fun HomeScreen(")
            .substringBefore("@Composable\nprivate fun WirdsSection(")

        assertFalse(
            "Home should not render the removed Continue goal card",
            "ContinueDhikrCard(" in screen,
        )
    }

    @Test
    fun `home places todays goals before prayer times`() {
        val screen = homeScreenSource()
            .substringAfter("fun HomeScreen(")
            .substringBefore("@Composable\nprivate fun WirdsSection(")
        val todaysGoalsBlock = screen.lastIndexOf("when (goalContentState) {")
        val prayerTimesBlock = screen.indexOf("if (prayerCardState.isLoading)")

        assertTrue("Today's goals block should be present", todaysGoalsBlock >= 0)
        assertTrue("Prayer times block should be present", prayerTimesBlock >= 0)
        assertTrue(
            "Today's goals must appear before prayer times",
            todaysGoalsBlock < prayerTimesBlock,
        )
    }

    private fun homeScreenSource(): String {
        val relativePath =
            "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/home/HomeScreen.kt"
        val workingDirectory = requireNotNull(System.getProperty("user.dir"))
        val candidates = generateSequence(File(workingDirectory)) { it.parentFile }
            .flatMap { directory ->
                sequenceOf(
                    directory.resolve(relativePath),
                    directory.resolve("awrad-android/$relativePath"),
                )
            }
        return candidates.firstOrNull(File::isFile)
            ?.readText()
            ?: error("Could not locate HomeScreen.kt from $workingDirectory")
    }
}
