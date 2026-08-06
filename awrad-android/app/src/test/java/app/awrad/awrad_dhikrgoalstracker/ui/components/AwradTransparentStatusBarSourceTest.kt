package app.awrad.awrad_dhikrgoalstracker.ui.components

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AwradTransparentStatusBarSourceTest {
    @Test
    fun `system status bar stays transparent without a shell color inset`() {
        val shell = source("ui/components/AwradShell.kt").withoutWhitespace()
        val activity = sourceFromMain("app/awrad/awrad_dhikrgoalstracker/MainActivity.kt")

        assertTrue(
            "AwradStatusBarStyle must keep the system status bar transparent",
            "window.statusBarColor=Color.Transparent.toArgb()" in shell,
        )
        assertFalse(
            "The app shell must not paint a route-independent box over page content",
            "statusBarContainerColor" in activity ||
                "windowInsetsTopHeight(WindowInsets.statusBars)" in activity,
        )
    }

    @Test
    fun `home and community render the mirrored top edge scrim`() {
        val shell = source("ui/components/AwradShell.kt").withoutWhitespace()
        val home = source("ui/screens/home/HomeScreen.kt")
        val community = source("ui/screens/community/CommunityScreen.kt")

        assertTrue("The shared shell must expose a reusable top edge scrim", "funAwradTopEdgeScrim(" in shell)
        assertTrue(
            "The top scrim must fade from the page background into transparent content",
            "0ftocolor" in shell &&
                "0.35ftocolor" in shell &&
                "0.72ftocolor.copy(alpha=0.72f)" in shell &&
                "1ftoColor.Transparent" in shell,
        )
        assertTrue("Home must render the top scrim as part of its page", "AwradTopEdgeScrim(" in home)
        assertTrue("Community must render the top scrim as part of its page", "AwradTopEdgeScrim(" in community)
    }

    @Test
    fun `home top edge scrim fades closer to the status bar`() {
        val shell = source("ui/components/AwradShell.kt").withoutWhitespace()
        val home = source("ui/screens/home/HomeScreen.kt").withoutWhitespace()
        val community = source("ui/screens/community/CommunityScreen.kt").withoutWhitespace()

        assertTrue(
            "The shared scrim must keep the existing fade extent as its default",
            "fadeExtentBelowStatusBar:Dp=48.dp" in shell,
        )
        assertTrue(
            "The scrim height must be derived from its configurable fade extent",
            ".height(statusBarInset+fadeExtentBelowStatusBar)" in shell,
        )
        assertTrue(
            "Home must pull the end of its top gradient upward",
            "fadeExtentBelowStatusBar=36.dp" in home,
        )
        assertFalse(
            "Community must retain the shared default fade extent",
            "fadeExtentBelowStatusBar=" in community,
        )
    }

    private fun source(relativePath: String): String =
        sourceFromMain("app/awrad/awrad_dhikrgoalstracker/$relativePath")

    private fun sourceFromMain(relativePath: String): String {
        val mainPath = "app/src/main/java/$relativePath"
        val workingDirectory = requireNotNull(System.getProperty("user.dir"))
        val file = generateSequence(File(workingDirectory)) { it.parentFile }
            .flatMap { directory ->
                sequenceOf(
                    directory.resolve(mainPath),
                    directory.resolve("awrad-android/$mainPath"),
                )
            }
            .firstOrNull(File::isFile)
            ?: error("Could not locate $mainPath from $workingDirectory")
        return file.readText()
    }

    private fun String.withoutWhitespace(): String = filterNot(Char::isWhitespace)
}
