package app.awrad.awrad_dhikrgoalstracker.ui.screens.counting

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CountingSurfaceParityTest {
    @Test
    fun `counting page keeps its transparent scaffold background`() {
        val countingBody = countingSource()
            .substringAfter("fun CountingScreen(")
            .substringBefore("private fun CountingTopBar(")

        assertTrue(
            "The counting scaffold should keep its original transparent background",
            countingBody.contains(
                "containerColor = androidx.compose.ui.graphics.Color.Transparent,",
            ),
        )
        assertFalse(
            "The counting page should not add a Home surface background",
            countingBody.contains(".background(MaterialTheme.colorScheme.surface)"),
        )
    }

    @Test
    fun `counting dhikr cards are white in light mode and match library cards in dark mode`() {
        val source = countingSource()
        val previewCards = source
            .substringAfter("private fun QuranDhikrPreviewCard(")
            .substringBefore("private fun DhikrTextSizeButton(")
        val librarySurface =
            "containerColor = if (isAwradDarkTheme()) {\n" +
                "                MaterialTheme.colorScheme.surfaceContainer\n" +
                "            } else {\n" +
                "                MaterialTheme.colorScheme.surface\n" +
                "            },"

        assertTrue(
            "Both text cards should use the Library card surface in dark mode and white surface in light mode",
            previewCards.split(librarySurface).size - 1 == 2,
        )
        assertFalse("The text cards should not overlay a gradient", previewCards.contains("Brush.horizontalGradient"))
        assertFalse("The text cards should remain borderless", previewCards.contains("border ="))
    }

    private fun countingSource(): String = countingScreenSource().readText()

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
