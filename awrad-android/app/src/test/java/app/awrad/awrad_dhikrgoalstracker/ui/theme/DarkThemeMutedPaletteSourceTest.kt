package app.awrad.awrad_dhikrgoalstracker.ui.theme

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DarkThemeMutedPaletteSourceTest {

    @Test
    fun `dark muted surfaces use neutral gray shades instead of green`() {
        val source = themeSource().readText()
        val darkScheme = source.substringAfter("private val DarkColorScheme")
            .substringBefore("@Composable")

        assertTrue("Muted outlines should use the neutral scale", "outlineVariant = Neutral30" in darkScheme)
        assertTrue(
            "Low muted surfaces should be neutral gray",
            "surfaceContainerLow = Color(0xFF181A18)" in darkScheme,
        )
        assertTrue(
            "Raised muted surfaces should be neutral gray",
            "surfaceContainerHigh = Color(0xFF282A28)" in darkScheme,
        )
        assertTrue(
            "Highest muted surfaces should use the neutral scale",
            "surfaceContainerHighest = Neutral20" in darkScheme,
        )
        assertFalse("Dark muted surfaces should not retain the green cast", "0xFF06100D" in darkScheme)
        assertFalse("Dark muted surfaces should not retain the green cast", "0xFF17251F" in darkScheme)
    }

    private fun themeSource(): File {
        val relativePath = "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/theme/Theme.kt"
        val workingDirectory = requireNotNull(System.getProperty("user.dir"))
        return generateSequence(File(workingDirectory)) { it.parentFile }
            .flatMap { directory ->
                sequenceOf(
                    directory.resolve(relativePath),
                    directory.resolve("awrad-android/$relativePath"),
                )
            }
            .firstOrNull(File::isFile)
            ?: error("Could not locate Theme.kt from $workingDirectory")
    }
}
