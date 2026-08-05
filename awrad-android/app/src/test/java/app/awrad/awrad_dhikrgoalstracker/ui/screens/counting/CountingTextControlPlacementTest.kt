package app.awrad.awrad_dhikrgoalstracker.ui.screens.counting

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

class CountingTextControlPlacementTest {
    @Test
    fun `text size action is before more menu and absent from preview cards`() {
        val source = countingScreenSource().readText()
        val topBarActions = source
            .substringAfter("actions = {")
            .substringBefore("DropdownMenu(")

        assertTrue(
            "The text-size action must appear immediately before the More action in the counting top bar",
            topBarActions.indexOf("DhikrTextSizeButton(") in 0 until topBarActions.indexOf("Icons.Default.MoreVert"),
        )

        val previewCards = source
            .substringAfter("private fun QuranDhikrPreviewCard(")
            .substringBefore("private fun DhikrTextSizeButton(")
        assertTrue(
            "Preview cards must not render the text-size action after it moves to the top bar",
            "DhikrTextSizeButton(" !in previewCards,
        )
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
