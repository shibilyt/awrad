package app.awrad.awrad_dhikrgoalstracker.ui.screens.home

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HomePrayerTimesSheetTest {
    @Test
    fun `configured prayer card opens prayer times sheet instead of settings`() {
        val home = source().readText()
            .substringAfter("fun HomeScreen(")
            .substringBefore("@Composable\nprivate fun WirdsSection(")
        val prayerCard = home
            .substringAfter("else if (prayerCardState.isVisible)")
            .substringBefore("} else {")

        assertTrue(
            "Configured prayer card should open the prayer times sheet",
            "showPrayerTimesSheet = true" in prayerCard,
        )
        assertFalse(
            "Configured prayer card should not navigate to Settings",
            "onClick = onNavigateToSettings" in prayerCard,
        )
    }

    @Test
    fun `home prayer sheet renders every available prayer row`() {
        val sheet = source().readText()
            .substringAfter("private fun PrayerTimesBottomSheet(")

        assertTrue("Home should render a modal prayer times sheet", "ModalBottomSheet(" in sheet)
        assertTrue("Prayer sheet should render the available prayer rows", "state.prayers.forEach" in sheet)
        assertTrue("Prayer sheet should show the configured location", "state.cityName" in sheet)
    }

    @Test
    fun `home prayer sheet keeps location setup in the sheet when coordinates are missing`() {
        val sheet = source().readText()
            .substringAfter("private fun PrayerTimesBottomSheet(")

        assertTrue("Prayer sheet should branch on whether a location exists", "if (state.isVisible)" in sheet)
        assertTrue("Prayer sheet should show the existing location prompt", "R.string.home_enable_prayer_title" in sheet)
        assertTrue("Prayer sheet should expose the location action", "onClick = onSetLocation" in sheet)
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
