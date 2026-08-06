package app.awrad.awrad_dhikrgoalstracker.ui.screens.home

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HomeBackgroundTest {
    @Test
    fun `home root uses the white surface background`() {
        val screen = source("ui/screens/home/HomeScreen.kt").readText()
            .substringAfter("fun HomeScreen(")
            .substringBefore("private fun HomeHeader(")

        assertTrue(
            "Home must use the theme surface, which is white in light mode",
            ".background(MaterialTheme.colorScheme.surface)" in screen,
        )
    }

    @Test
    fun `home owns its top scrim beneath the transparent status bar`() {
        val mainActivity = source("MainActivity.kt").readText()
        val home = source("ui/screens/home/HomeScreen.kt").readText()

        assertFalse(
            "The app shell must not cover Home's edge-to-edge content",
            "statusBarContainerColor" in mainActivity,
        )
        assertTrue("Home must render its own top edge scrim", "AwradTopEdgeScrim(" in home)
    }

    @Test
    fun `settings icon uses the muted home content color`() {
        val header = source("ui/screens/home/HomeScreen.kt").readText()
            .substringAfter("private fun HomeHeader(")
            .substringBefore("private fun ContinueDhikrCard(")

        assertTrue(
            "Settings icon must use the same muted color as secondary Home content",
            "tint = visuals.secondaryTextColor" in header,
        )
        assertTrue(
            "Settings button surface must match the prayer card surface",
            "color = MaterialTheme.colorScheme.surfaceContainer" in header,
        )
    }

    @Test
    fun `prayer card uses the goals and library content background`() {
        val prayerCard = source("ui/screens/home/HomeScreen.kt").readText()
            .substringAfter("private fun PrayerRhythmCard(")
            .substringBefore("private fun PrayerTimesPromptCard(")

        assertTrue(
            "Prayer card must use the shared content-section color",
            "color = MaterialTheme.colorScheme.surfaceContainer" in prayerCard,
        )
    }

    @Test
    fun `prayer times prompt has the shared content background`() {
        val prayerPrompt = source("ui/screens/home/HomeScreen.kt").readText()
            .substringAfter("private fun PrayerTimesPromptCard(")
            .substringBefore("private fun PrayerRhythmCard(")

        assertTrue(
            "The prayer-times prompt must remain visible against the Home surface",
            "color = MaterialTheme.colorScheme.surfaceContainer" in prayerPrompt,
        )
    }

    @Test
    fun `featured wird cards use the goals and library content background`() {
        val featuredWirds = source("ui/screens/home/HomeScreen.kt").readText()
            .substringAfter("private fun WirdsSection(")
            .substringBefore("private fun ContinueDhikrCard(")

        assertTrue(
            "Featured Wird cards must use the shared content-section color",
            "containerColor = MaterialTheme.colorScheme.surfaceContainer" in featuredWirds,
        )
    }

    private fun source(relativeSourcePath: String): File {
        val relativePath =
            "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/$relativeSourcePath"
        val workingDirectory = requireNotNull(System.getProperty("user.dir"))
        val candidates = generateSequence(File(workingDirectory)) { it.parentFile }
            .flatMap { directory ->
                sequenceOf(
                    directory.resolve(relativePath),
                    directory.resolve("awrad-android/$relativePath"),
                )
            }
        return candidates.firstOrNull(File::isFile)
            ?: error("Could not locate $relativeSourcePath from $workingDirectory")
    }
}
