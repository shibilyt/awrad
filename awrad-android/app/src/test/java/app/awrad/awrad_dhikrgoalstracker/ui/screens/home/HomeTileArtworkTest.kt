package app.awrad.awrad_dhikrgoalstracker.ui.screens.home

import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HomeTileArtworkTest {
    @Test
    fun `minimal artwork cards do not use a drawn outline`() {
        val screen = source("main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/home/HomeScreen.kt")
            .readText()
        val continueCard = screen
            .substringAfter("private fun ContinueDhikrCard(")
            .substringBefore("private fun GoalWithProgress.continueSubtitle()")
        val goalsCard = screen
            .substringAfter("private fun TodayGoalsSection(")
            .substringBefore("private fun GoalIconBadge(")

        assertFalse(
            "Continue card separation must come from its artwork, not an outline",
            "showBorder" in continueCard,
        )
        assertFalse(
            "Today's Goals card separation must come from its artwork, not an outline",
            "showBorder" in goalsCard,
        )
    }

    @Test
    fun `home cards use dedicated minimal artwork for light and dark themes`() {
        val visuals = source("main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/home/HomeVisuals.kt")
            .readText()

        listOf(
            "home_continue_minimal_light",
            "home_continue_minimal_dark",
            "home_goals_minimal_light",
            "home_goals_minimal_dark",
        ).forEach { resourceName ->
            assertTrue(
                "$resourceName must be mapped by HomeVisuals",
                "R.drawable.$resourceName" in visuals,
            )
        }

        assertFalse("Continue must no longer use landscape artwork", "home_featured_" in visuals)
        assertFalse("Goals must no longer use landscape artwork", "home_goals_day" in visuals)
        assertFalse("Goals must no longer use night landscape artwork", "home_goals_night" in visuals)
    }

    @Test
    fun `minimal home artwork is a consistent two to one landscape`() {
        listOf(
            "home_continue_minimal_light.png",
            "home_continue_minimal_dark.png",
            "home_goals_minimal_light.png",
            "home_goals_minimal_dark.png",
        ).forEach { fileName ->
            val imageFile = source("main/res/drawable-nodpi/$fileName")
            val bytes = imageFile.readBytes()
            require(bytes.size >= 24) { "$fileName must contain a complete PNG header" }
            val pngSignature = byteArrayOf(
                0x89.toByte(), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
            )
            require(bytes.take(8).toByteArray().contentEquals(pngSignature)) {
                "$fileName must be a PNG image"
            }
            val dimensions = ByteBuffer.wrap(bytes, 16, 8).order(ByteOrder.BIG_ENDIAN)
            val width = dimensions.int
            val height = dimensions.int

            assertTrue("$fileName must be landscape", width > height)
            assertTrue(
                "$fileName must use a 2:1 aspect ratio",
                kotlin.math.abs((width.toDouble() / height) - 2.0) < 0.01,
            )
        }
    }

    private fun source(relativeAppPath: String): File {
        val workingDirectory = requireNotNull(System.getProperty("user.dir"))
        val candidates = generateSequence(File(workingDirectory)) { it.parentFile }
            .flatMap { directory ->
                sequenceOf(
                    directory.resolve("app/src/$relativeAppPath"),
                    directory.resolve("awrad-android/app/src/$relativeAppPath"),
                )
            }
        return candidates.firstOrNull(File::isFile)
            ?: error("Could not locate $relativeAppPath from $workingDirectory")
    }
}
