package app.awrad.awrad_dhikrgoalstracker.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class RemembranceProviderTest {

    private val poolSize = 14

    @Test
    fun `index is deterministic for a fixed date`() {
        val date = LocalDate.of(2026, 7, 3)
        val first = RemembranceProvider.indexForDate(date, poolSize)
        val second = RemembranceProvider.indexForDate(date, poolSize)
        assertEquals(first, second)
        // dayOfYear for 2026-07-03 is 184; 184 % 14 == 2
        assertEquals(184 % poolSize, first)
    }

    @Test
    fun `index is always in bounds across a full year`() {
        var date = LocalDate.of(2024, 1, 1) // leap year → 366 days
        val end = LocalDate.of(2024, 12, 31)
        while (!date.isAfter(end)) {
            val index = RemembranceProvider.indexForDate(date, poolSize)
            assertTrue("index $index out of bounds for $date", index in 0 until poolSize)
            date = date.plusDays(1)
        }
    }

    @Test
    fun `consecutive days rotate to a different item`() {
        // Within a run shorter than the pool size, each day advances the index by 1 (mod size),
        // so consecutive days differ.
        var date = LocalDate.of(2026, 3, 1)
        repeat(poolSize) {
            val today = RemembranceProvider.indexForDate(date, poolSize)
            val tomorrow = RemembranceProvider.indexForDate(date.plusDays(1), poolSize)
            assertTrue("expected rotation between $date and next day", today != tomorrow)
            date = date.plusDays(1)
        }
    }

    @Test
    fun `notification text prefers translation when shown otherwise arabic`() {
        val english = Remembrance("عربي", "English", "src", showTranslation = true)
        assertEquals("English", english.notificationText)

        val arabic = Remembrance("عربي", "English", "src", showTranslation = false)
        assertEquals("عربي", arabic.notificationText)

        val blankTranslation = Remembrance("عربي", "", "src", showTranslation = true)
        assertEquals("عربي", blankTranslation.notificationText)
    }
}
