package app.awrad.awrad_dhikrgoalstracker.ui.screens.counting

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CountingCoachMarkStepTest {
    @Test
    fun `counting guide skips the redundant progress step`() {
        val source = coachMarkSource().readText()
        val steps = source
            .substringAfter("val steps = remember")
            .substringBefore("var index by")

        assertFalse(steps.contains("targets.heroPanel"))
        assertFalse(steps.contains("coach_progress_title"))
        assertFalse(steps.contains("coach_progress_body"))
    }

    @Test
    fun `counting guide spotlights the exact counter bounds`() {
        val source = countingScreenSource().readText()

        assertTrue(source.contains("onCounterPositioned = { countButtonRect = it }"))
        assertFalse(source.contains("heroPanelRect"))
    }

    private fun coachMarkSource(): File = sourceFile(
        "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/counting/CountingCoachMarkOverlay.kt",
    )

    private fun countingScreenSource(): File = sourceFile(
        "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/counting/CountingScreen.kt",
    )

    private fun sourceFile(relativePath: String): File {
        val workingDirectory = requireNotNull(System.getProperty("user.dir"))
        val candidates = generateSequence(File(workingDirectory)) { it.parentFile }
            .map { directory -> directory.resolve(relativePath) }
            .plus(
                generateSequence(File(workingDirectory)) { it.parentFile }
                    .map { directory -> directory.resolve("awrad-android/$relativePath") },
            )
        return candidates.firstOrNull(File::isFile)
            ?: error("Could not locate $relativePath from $workingDirectory")
    }
}
