package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

class CreateGoalNavigationSourceTest {

    @Test
    fun `backtracking from goal type clears selection before opening entry picker`() {
        val source = sourceFile(
            "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/CreateGoalViewModel.kt",
        ).readText()

        assertTrue(
            "Backtracking into the entry picker must not retain the selected dhikr as a change-flow marker",
            Regex(
                """setState\(\s*state\.copy\(\s*mode = GoalCreationMode\.SelectDhikr,\s*selectedDhikr = null,\s*dhikrReturnMode = GoalCreationMode\.SelectShape""",
            ).containsMatchIn(source),
        )
    }

    private fun sourceFile(relativePath: String): File {
        val workingDirectory = requireNotNull(System.getProperty("user.dir"))
        return generateSequence(File(workingDirectory)) { it.parentFile }
            .flatMap { directory ->
                sequenceOf(
                    directory.resolve(relativePath),
                    directory.resolve("awrad-android/$relativePath"),
                )
            }
            .firstOrNull(File::isFile)
            ?: error("Could not locate $relativePath from $workingDirectory")
    }
}
