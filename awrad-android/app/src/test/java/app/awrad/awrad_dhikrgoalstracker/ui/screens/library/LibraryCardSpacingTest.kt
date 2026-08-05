package app.awrad.awrad_dhikrgoalstracker.ui.screens.library

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

class LibraryCardSpacingTest {
    @Test
    fun `dhikr cards use the same eight dp gap as goal cards`() {
        val pane = libraryScreenSource().readText()
            .substringAfter("private fun DhikrLibraryPane(")
            .substringBefore("private fun WirdLibraryPane(")

        assertTrue(
            "Library dhikr cards must use the Goals list's 8.dp rhythm",
            "verticalArrangement = Arrangement.spacedBy(8.dp)" in pane,
        )
    }

    private fun libraryScreenSource(): File {
        val relativePath =
            "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/library/LibraryScreen.kt"
        val workingDirectory = requireNotNull(System.getProperty("user.dir"))
        val candidates = generateSequence(File(workingDirectory)) { it.parentFile }
            .flatMap { directory ->
                sequenceOf(
                    directory.resolve(relativePath),
                    directory.resolve("awrad-android/$relativePath"),
                )
            }
        return candidates.firstOrNull(File::isFile)
            ?: error("Could not locate LibraryScreen.kt from $workingDirectory")
    }
}
