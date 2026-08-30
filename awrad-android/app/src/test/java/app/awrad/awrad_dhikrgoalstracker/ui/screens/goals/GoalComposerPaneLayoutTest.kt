package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GoalComposerPaneLayoutTest {

    @Test
    fun advancedComposerKeepsDhikrChangeInTheHeaderWithoutADhikrCard() {
        val pane = sourceFile("GoalComposerPane.kt")
            .readText()
            .substringAfter("fun GoalComposerPane(")
            .substringBefore("// ─── Goal sentence hero")
        val heroIndex = pane.indexOf("GoalSentenceHero(")
        val changeIndex = pane.indexOf("R.string.composer_change_dhikr")
        val scrollContentIndex = pane.indexOf(".weight(1f)")

        assertFalse(
            "The advanced composer must not render the dhikr header card",
            "DhikrHeaderCard(" in pane,
        )
        assertTrue("The goal statement must render before Change dhikr", heroIndex >= 0 && heroIndex < changeIndex)
        assertTrue(
            "Change dhikr must stay in the top header, outside the scrollable form",
            changeIndex >= 0 && changeIndex < scrollContentIndex,
        )
        assertTrue(
            "Change dhikr must only render while the goal statement is expanded",
            "if (!previewCollapsed && canChangeDhikr)" in pane,
        )
    }

    private fun sourceFile(name: String): File {
        val relativePath =
            "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/$name"
        val workingDirectory = requireNotNull(System.getProperty("user.dir"))
        return generateSequence(File(workingDirectory)) { it.parentFile }
            .flatMap { directory ->
                sequenceOf(
                    directory.resolve(relativePath),
                    directory.resolve("awrad-android/$relativePath"),
                )
            }
            .firstOrNull(File::isFile)
            ?: error("Could not locate $name from $workingDirectory")
    }
}
