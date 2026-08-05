package app.awrad.awrad_dhikrgoalstracker.ui.screens.home

import java.io.File
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
    fun `home status bar uses the white surface background`() {
        val statusBarRoutes = source("MainActivity.kt").readText()
            .substringAfter("private val surfaceStatusBarRoutes = setOf(")
            .substringBefore("private fun String?.isSurfaceStatusBarRoute()")

        assertTrue(
            "Home must use the shell's white surface status bar in light mode",
            "AwradDestination.Home.route" in statusBarRoutes,
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
