package app.awrad.awrad_dhikrgoalstracker.ui.screens.counting

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CountingHeroLayoutTest {
    @Test
    fun `counting hero keeps the counter from filling the whole viewport`() {
        val heroSource = countingScreenSource()
            .readText()
            .substringAfter("private fun CountingHeroPanel")
            .substringBefore("private fun CountingHintOrSyncAlert")

        assertTrue(
            "The primary counter should have a bounded diameter",
            heroSource.contains(".widthIn(max = 320.dp)"),
        )
    }

    @Test
    fun `slot progress hero uses the same bounded counter size`() {
        val slotSource = countingScreenSource()
            .readText()
            .substringAfter("private fun SlotProgressCard")
            .substringBefore("private fun HeroMetricChip")

        assertTrue(
            "Slot progress should use the same counter geometry as the default hero",
            slotSource.contains(".widthIn(max = 320.dp)"),
        )
    }

    @Test
    fun `hero stage centers the counter instead of pinning it to the bottom`() {
        val source = countingScreenSource().readText()
        val heroHost = source
            .substringAfter("// Slot-complete banner: visible when current slot is done but other slots remain.")
            .substringBefore("// First-run guide: shown once, after layout is measured.")

        assertTrue(
            "The hero host should share the remaining space and center its content",
            heroHost.contains(".fillMaxWidth()\n                    .weight(1f)"),
        )
        assertTrue(heroHost.contains("contentAlignment = Alignment.Center,"))
        assertFalse(heroHost.contains("Spacer(modifier = Modifier.weight(1f))"))
        assertFalse(heroHost.contains("contentAlignment = Alignment.BottomCenter,"))
    }

    private fun countingScreenSource(): File {
        val relativePath =
            "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/counting/CountingScreen.kt"
        val workingDirectory = requireNotNull(System.getProperty("user.dir"))
        val candidates = generateSequence(File(workingDirectory)) { it.parentFile }
            .flatMap { directory ->
                sequenceOf(
                    directory.resolve(relativePath),
                    directory.resolve("awrad-android/$relativePath"),
                )
            }
        return candidates.firstOrNull(File::isFile)
            ?: error("Could not locate CountingScreen.kt from $workingDirectory")
    }
}
