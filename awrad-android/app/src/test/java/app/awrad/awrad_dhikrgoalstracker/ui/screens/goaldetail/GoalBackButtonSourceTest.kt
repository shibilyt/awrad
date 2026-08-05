package app.awrad.awrad_dhikrgoalstracker.ui.screens.goaldetail

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

class GoalBackButtonSourceTest {

    @Test
    fun `goal detail back action uses the shared circular treatment`() {
        val source = sourceFile(
            "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goaldetail/GoalDetailScreen.kt",
        ).readText()
        val topBar = source.substringAfter("private fun GoalDetailTopBar(")

        assertTrue("Goal detail should use a filled circular back action", "FilledIconButton(" in topBar)
        assertTrue(
            "Goal detail back circle should use the muted surface token",
            "containerColor = MaterialTheme.colorScheme.surfaceContainerHighest" in topBar,
        )
    }

    @Test
    fun `create goal back action uses the shared circular treatment`() {
        val source = sourceFile(
            "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/CreateGoalScreen.kt",
        ).readText()
        val topBar = source.substringAfter("topBar = {")
            .substringBefore("contentWindowInsets =")

        assertTrue("Create goal should use a filled circular back action", "FilledIconButton(" in topBar)
        assertTrue(
            "Create goal back circle should use the muted surface token",
            "containerColor = MaterialTheme.colorScheme.surfaceContainerHighest" in topBar,
        )
        assertTrue(
            "Create goal back action should remain accessible",
            "contentDescription = stringResource(R.string.action_back)" in topBar,
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
