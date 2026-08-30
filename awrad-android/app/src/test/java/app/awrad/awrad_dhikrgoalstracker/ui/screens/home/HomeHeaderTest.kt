package app.awrad.awrad_dhikrgoalstracker.ui.screens.home

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Test

class HomeHeaderTest {
    @Test
    fun `home header does not render the redundant today title`() {
        val header = source().readText()
            .substringAfter("private fun HomeHeader(")
            .substringBefore("private fun HomeCardSurface(")

        assertFalse(
            "Home should not render a standalone Today title",
            "R.string.home_today" in header,
        )
    }

    private fun source(): File {
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
            ?: error("Could not locate HomeScreen.kt from $workingDirectory")
    }
}
