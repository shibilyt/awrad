package app.awrad.awrad_dhikrgoalstracker.ui.screens.counting

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class CountingRingProgressTest {
    @Test
    fun `target is the outer ring bound when maximum is absent`() {
        assertEquals(100, countingRingUpperBound(targetCount = 100, maximumCount = null))
    }

    @Test
    fun `explicit maximum takes precedence over target`() {
        assertEquals(313, countingRingUpperBound(targetCount = 100, maximumCount = 313))
    }

    @Test
    fun `ring uses the minimum as its active target before the checkpoint`() {
        val progress = countingRingProgress(
            currentCount = 2,
            minimumCount = 5,
            maximumCount = 10,
        )

        assertEquals(2f / 5f, progress.progress, 0.0001f)
        assertEquals(2f / 5f, progress.minimumSegmentProgress, 0.0001f)
        assertEquals(0f, progress.remainingSegmentProgress, 0.0001f)
        assertEquals(5f / 10f, progress.minimumCheckpoint, 0.0001f)
        assertEquals(5, progress.activeTarget)
    }

    @Test
    fun `ring switches to the final target at the minimum and keeps the checkpoint`() {
        val progress = countingRingProgress(
            currentCount = 5,
            minimumCount = 5,
            maximumCount = 10,
        )

        assertEquals(5f / 10f, progress.progress, 0.0001f)
        assertEquals(5f / 10f, progress.minimumSegmentProgress, 0.0001f)
        assertEquals(0f, progress.remainingSegmentProgress, 0.0001f)
        assertEquals(5f / 10f, progress.minimumCheckpoint, 0.0001f)
        assertEquals(10, progress.activeTarget)
    }

    @Test
    fun `ring continues toward the final target after the checkpoint`() {
        val progress = countingRingProgress(
            currentCount = 7,
            minimumCount = 5,
            maximumCount = 10,
        )

        assertEquals(7f / 10f, progress.progress, 0.0001f)
        assertEquals(5f / 10f, progress.minimumSegmentProgress, 0.0001f)
        assertEquals(2f / 10f, progress.remainingSegmentProgress, 0.0001f)
        assertEquals(5f / 10f, progress.minimumCheckpoint, 0.0001f)
        assertEquals(10, progress.activeTarget)
    }

    @Test
    fun `ring is complete at the final target while checkpoint remains fixed`() {
        val progress = countingRingProgress(
            currentCount = 10,
            minimumCount = 5,
            maximumCount = 10,
        )

        assertEquals(1f, progress.progress, 0f)
        assertEquals(5f / 10f, progress.minimumSegmentProgress, 0.0001f)
        assertEquals(5f / 10f, progress.remainingSegmentProgress, 0.0001f)
        assertEquals(5f / 10f, progress.minimumCheckpoint, 0.0001f)
        assertEquals(10, progress.activeTarget)
    }

    @Test
    fun `invalid ring bounds are rejected`() {
        assertThrows(IllegalArgumentException::class.java) {
            countingRingProgress(currentCount = 1, minimumCount = 100, maximumCount = 99)
        }
    }

    @Test
    fun `minimum rail uses target color and remaining rail uses minimum color`() {
        val source = File(
            "src/main/java/app/awrad/awrad_dhikrgoalstracker/ui/screens/counting/CountingScreen.kt",
        ).readText()
        val ringSource = source.substringAfter("private fun CountingProgressRing")

        assertTrue(ringSource.contains("val minimumRailColor = CountRingAccent"))
        assertTrue(ringSource.contains("val remainingRailColor = MaterialTheme.colorScheme.primary"))
        assertTrue(ringSource.contains("color = minimumRailColor"))
        assertTrue(ringSource.contains("color = remainingRailColor"))
    }
}
