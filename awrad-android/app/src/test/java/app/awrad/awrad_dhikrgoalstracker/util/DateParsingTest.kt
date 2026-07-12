package app.awrad.awrad_dhikrgoalstracker.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.LocalDate

class DateParsingTest {

    @Test
    fun `safe parser trims valid date text`() {
        assertEquals(LocalDate.parse("2026-06-02"), " 2026-06-02 ".toLocalDateOrNull())
    }

    @Test
    fun `safe parser returns null for malformed date text`() {
        assertNull("legacy-date".toLocalDateOrNull())
    }

    @Test
    fun `safe parser repairs malformed date text with fallback`() {
        val fallback = LocalDate.parse("2026-06-03")

        assertEquals(fallback, "legacy-date".toLocalDateOr(fallback))
    }
}
