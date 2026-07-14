package app.awrad.awrad_dhikrgoalstracker.ui.screens.counting

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

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
    fun `minimum and maximum rings move from the same count at their own rates`() {
        val progress = countingRingProgress(
            currentCount = 17,
            minimumCount = 100,
            maximumCount = 313,
        )

        assertEquals(0.17f, progress.minimum, 0.0001f)
        assertEquals(17f / 313f, progress.maximum, 0.0001f)
    }

    @Test
    fun `minimum locks complete while maximum keeps moving`() {
        val progress = countingRingProgress(
            currentCount = 200,
            minimumCount = 100,
            maximumCount = 313,
        )

        assertEquals(1f, progress.minimum, 0f)
        assertEquals(200f / 313f, progress.maximum, 0.0001f)
    }

    @Test
    fun `both rings are complete at maximum`() {
        val progress = countingRingProgress(
            currentCount = 313,
            minimumCount = 100,
            maximumCount = 313,
        )

        assertEquals(1f, progress.minimum, 0f)
        assertEquals(1f, progress.maximum, 0f)
    }

    @Test
    fun `invalid ring bounds are rejected`() {
        assertThrows(IllegalArgumentException::class.java) {
            countingRingProgress(currentCount = 1, minimumCount = 100, maximumCount = 99)
        }
    }
}
