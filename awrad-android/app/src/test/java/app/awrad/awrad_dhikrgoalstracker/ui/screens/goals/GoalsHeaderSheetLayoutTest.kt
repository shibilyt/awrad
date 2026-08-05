package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GoalsHeaderSheetLayoutTest {
    @Test
    fun `goals uses the same edge to edge scaffold as library`() {
        val source = goalsScreenSource().readText()
        val screen = source
            .substringAfter("fun GoalsScreen(")
            .substringBefore("private fun ActiveGoalsPane(")

        assertTrue("Goals must use Library's transparent scaffold", "containerColor = Color.Transparent" in screen)
        assertTrue("Goals must draw its header behind the status bar", "contentWindowInsets = WindowInsets(0)" in screen)
        assertFalse(
            "Goals must not override Library's edge-to-edge status bar treatment",
            "AwradStatusBarStyle(" in screen,
        )
        val statusBarRoutes = mainActivitySource().readText()
            .substringAfter("private val surfaceStatusBarRoutes = setOf(")
            .substringBefore("private fun String?.isSurfaceStatusBarRoute()")
        assertTrue(
            "Goals must use the same shell status-bar surface as Library",
            "AwradDestination.Goals.route" in statusBarRoutes,
        )
    }

    @Test
    fun `goals title uses the same display size as library`() {
        val source = goalsScreenSource().readText()
        val header = source
            .substringAfter("text = stringResource(R.string.goals_title)")
            .substringBefore("IconButton(onClick = onNavigateToCreateGoal)")

        assertTrue(
            "Goals title must use the same displayMedium style as Library",
            "style = MaterialTheme.typography.displayMedium" in header,
        )
    }

    @Test
    fun `tabs sit above a rounded sheet containing the goals pager`() {
        val source = goalsScreenSource().readText()
        val screen = source
            .substringAfter("fun GoalsScreen(")
            .substringBefore("private fun ActiveGoalsPane(")

        val tabsIndex = screen.indexOf("AwradPagerTabs(")
        val sheetIndex = screen.indexOf("Surface(")
        assertTrue("Goals tabs must be rendered before the content sheet", tabsIndex in 0 until sheetIndex)

        val sheet = screen.substring(sheetIndex)
        assertTrue(
            "Goals content must use the same rounded top corners as Library",
            "shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)" in sheet,
        )
        assertTrue("The goals pager must live inside the rounded sheet", "HorizontalPager(" in sheet)
    }

    @Test
    fun `goal cards use the same container color as library dhikr cards`() {
        val goalCard = goalsScreenSource().readText()
            .substringAfter("private fun GoalListItem(")
            .substringBefore("private fun goalTag(")
            .filterNot(Char::isWhitespace)
        val sharedCardColor =
            "containerColor=if(isAwradDarkTheme()){MaterialTheme.colorScheme.surfaceContainer}" +
                "else{MaterialTheme.colorScheme.surface}"

        assertTrue(
            "Goal cards must use the same light and dark surfaces as Library dhikr cards",
            sharedCardColor in goalCard,
        )
    }

    private fun goalsScreenSource(): File {
        val relativePath =
            "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/goals/GoalsScreen.kt"
        val workingDirectory = requireNotNull(System.getProperty("user.dir"))
        val candidates = generateSequence(File(workingDirectory)) { it.parentFile }
            .flatMap { directory ->
                sequenceOf(
                    directory.resolve(relativePath),
                    directory.resolve("awrad-android/$relativePath"),
                )
            }
        return candidates.firstOrNull(File::isFile)
            ?: error("Could not locate GoalsScreen.kt from $workingDirectory")
    }

    private fun mainActivitySource(): File {
        val relativePath =
            "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/MainActivity.kt"
        val workingDirectory = requireNotNull(System.getProperty("user.dir"))
        val candidates = generateSequence(File(workingDirectory)) { it.parentFile }
            .flatMap { directory ->
                sequenceOf(
                    directory.resolve(relativePath),
                    directory.resolve("awrad-android/$relativePath"),
                )
            }
        return candidates.firstOrNull(File::isFile)
            ?: error("Could not locate MainActivity.kt from $workingDirectory")
    }
}
