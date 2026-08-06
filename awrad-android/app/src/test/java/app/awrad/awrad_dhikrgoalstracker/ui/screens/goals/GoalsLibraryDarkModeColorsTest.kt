package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GoalsLibraryDarkModeColorsTest {
    @Test
    fun `dark mode uses grey headers over darker content sheets`() {
        listOf(
            "Goals" to source("ui/screens/goals/GoalsScreen.kt").readText(),
            "Library" to source("ui/screens/library/LibraryScreen.kt").readText(),
        ).forEach { (screenName, source) ->
            val compactSource = source.withoutWhitespace()

            assertTrue(
                "$screenName must use the grey container surface for its dark-mode header",
                "valheaderBackgroundColor=if(isAwradDarkTheme()){MaterialTheme.colorScheme.surfaceContainer}else{MaterialTheme.colorScheme.surface}" in compactSource,
            )
            assertTrue(
                "$screenName must use the darker surface for its dark-mode content",
                "valcontentBackgroundColor=if(isAwradDarkTheme()){MaterialTheme.colorScheme.surface}else{MaterialTheme.colorScheme.surfaceContainer}" in compactSource,
            )
            assertTrue(
                "$screenName content sheet must consume the resolved content background",
                "color=contentBackgroundColor" in compactSource,
            )
        }
    }

    @Test
    fun `dark mode uses grey containers for goal and dhikr cards`() {
        val goalCard = source("ui/screens/goals/GoalsScreen.kt").readText()
            .substringAfter("private fun GoalListItem(")
            .substringBefore("private fun goalTag(")
            .withoutWhitespace()
        val dhikrCard = source("ui/screens/library/LibraryScreen.kt").readText()
            .substringAfter("private fun LibraryDhikrRow(")
            .withoutWhitespace()
        val expectedColor =
            "containerColor=if(isAwradDarkTheme()){MaterialTheme.colorScheme.surfaceContainer}else{MaterialTheme.colorScheme.surface}"

        assertTrue("Goal cards must use the reversed dark-mode surface", expectedColor in goalCard)
        assertTrue("Dhikr cards must use the reversed dark-mode surface", expectedColor in dhikrCard)
    }

    @Test
    fun `inactive tabs use the content area background`() {
        listOf(
            "Goals" to source("ui/screens/goals/GoalsScreen.kt").readText(),
            "Library" to source("ui/screens/library/LibraryScreen.kt").readText(),
        ).forEach { (screenName, source) ->
            val tabs = source
                .substringAfter("AwradPagerTabs(")
                .substringBefore("\n                )")

            assertTrue(
                "$screenName inactive tabs must blend into the content area",
                "unselectedColor = contentBackgroundColor" in tabs,
            )
        }
    }

    @Test
    fun `library wird cards use the same reversed surface as dhikr cards`() {
        val libraryScreen = source("ui/screens/library/LibraryScreen.kt").readText()
            .substringAfter("else -> WirdLibraryPane(")
            .substringBefore("\n                                )")
            .withoutWhitespace()
        val wirdSource = source("ui/screens/wird/WirdListScreen.kt").readText()
            .withoutWhitespace()
        val expectedColor =
            "cardContainerColor=if(isAwradDarkTheme()){MaterialTheme.colorScheme.surfaceContainer}else{MaterialTheme.colorScheme.surface}"

        assertTrue(
            "Library must give Wird cards the same dark-mode surface as dhikr cards",
            expectedColor in libraryScreen,
        )
        assertTrue(
            "WirdLibraryPane must forward its card color to every Wird card",
            "WirdCard(it,onNavigateToWird,cardContainerColor)" in wirdSource,
        )
        assertTrue(
            "WirdCard must forward the Library override to the shared catalog card",
            "containerColor=containerColor" in wirdSource,
        )
    }

    @Test
    fun `status bar stays transparent across navigation routes`() {
        val shell = sourceFromMain(
            "app/awrad/awrad_dhikrgoalstracker/ui/components/AwradShell.kt",
        ).readText()
        val statusBarStyle = shell
            .substringAfter("fun AwradStatusBarStyle(")
            .substringBefore("@OptIn(ExperimentalMaterial3Api::class)")
            .withoutWhitespace()

        assertTrue(
            "Every route must keep the system status bar transparent",
            "window.statusBarColor=Color.Transparent.toArgb()" in statusBarStyle,
        )
        assertFalse(
            "Routes may change icon contrast but must not paint the system bar",
            "window.statusBarColor=color.toArgb()" in statusBarStyle,
        )
    }

    private fun String.withoutWhitespace(): String = filterNot(Char::isWhitespace)

    private fun source(relativePath: String): File =
        sourceFromMain("app/awrad/awrad_dhikrgoalstracker/$relativePath")

    private fun sourceFromMain(relativePath: String): File {
        val mainPath = "app/src/main/java/$relativePath"
        val workingDirectory = requireNotNull(System.getProperty("user.dir"))
        val candidates = generateSequence(File(workingDirectory)) { it.parentFile }
            .flatMap { directory ->
                sequenceOf(
                    directory.resolve(mainPath),
                    directory.resolve("awrad-android/$mainPath"),
                )
            }
        return candidates.firstOrNull(File::isFile)
            ?: error("Could not locate $mainPath from $workingDirectory")
    }
}
