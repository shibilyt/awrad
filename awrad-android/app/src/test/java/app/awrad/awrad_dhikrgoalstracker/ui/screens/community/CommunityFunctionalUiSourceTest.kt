package app.awrad.awrad_dhikrgoalstracker.ui.screens.community

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CommunityFunctionalUiSourceTest {
    @Test
    fun `community tabs render real explore and goals content`() {
        val source = sourceFile("CommunityScreen.kt").readText()

        assertTrue("Explore must render a real feed", "CommunityExploreFeed(" in source)
        assertTrue("Goals must render a real feed", "CommunityGoalsFeed(" in source)
        assertFalse("The Community tabs must not stop at a placeholder", "CommunityTabPlaceholder(" in source)
    }

    @Test
    fun `feed exposes navigation for posts goals and circles`() {
        val source = sourceFile("CommunityLandingFeed.kt").readText()

        assertTrue("The feed must navigate to post detail", "onOpenPost" in source)
        assertTrue("The feed must navigate to goal creation", "onNavigateToCreateGoal" in source)
        assertTrue("The feed must navigate to circles", "onNavigateToCircles" in source)
        assertTrue("Posts must expose an interaction state", "rememberSaveable" in source)
    }

    @Test
    fun `community destinations contain usable circles and goals surfaces`() {
        val source = sourceFile("CommunityDestinations.kt").readText()

        assertTrue("Circles must render more than one destination card", "CommunityCircleCard(" in source)
        assertTrue("Challenges must render a goal action", "CommunityGoalCard(" in source)
        assertTrue("Destination actions must give feedback", "SnackbarHostState" in source)
    }

    private fun sourceFile(name: String): File {
        val relativePath =
            "app/src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/community/$name"
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
