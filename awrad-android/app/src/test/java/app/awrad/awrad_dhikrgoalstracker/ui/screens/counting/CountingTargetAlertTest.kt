package app.awrad.awrad_dhikrgoalstracker.ui.screens.counting

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class CountingTargetAlertTest {
    @Test
    fun `target reached alert is rendered inside the count circle`() {
        val source = File(
            "src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/counting/CountingScreen.kt",
        ).readText()
        val heroPanelSource = source
            .substringAfter("private fun CountingHeroPanel")
            .substringBefore("private fun CountingProgressCaption")
        val slotCardSource = source
            .substringAfter("private fun SlotProgressCard")
            .substringBefore("private fun CountingProgressRing")

        assertTrue(heroPanelSource.contains("TargetReachedCircleMessage"))
        assertTrue(slotCardSource.contains("TargetReachedCircleMessage"))
        assertFalse(source.contains("TargetReachedCapCard("))

        val messageSource = source
            .substringAfter("private fun TargetReachedCircleMessage")
            .substringBefore("@Composable")
        assertFalse(messageSource.contains("Surface("))
        assertFalse(messageSource.contains("Card("))
        assertFalse(messageSource.contains(".background("))
        assertTrue(messageSource.contains("color = MaterialTheme.colorScheme.onSurface"))
        assertFalse(messageSource.contains("color = MaterialTheme.colorScheme.onSurfaceVariant"))
    }

    @Test
    fun `target reached alert offers to keep counting`() {
        val source = File(
            "src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/counting/CountingScreen.kt",
        ).readText()

        assertTrue(source.contains("R.string.action_keep_counting"))
        assertTrue(source.contains("onKeepCounting"))
    }
}
