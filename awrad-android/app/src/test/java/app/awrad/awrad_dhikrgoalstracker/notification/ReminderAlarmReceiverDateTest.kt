package app.awrad.awrad_dhikrgoalstracker.notification

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate

class ReminderAlarmReceiverDateTest {

    @Test
    fun `malformed occurrence date falls back to effective date text`() {
        val resolved = resolveReminderDate(
            occurrenceDate = "legacy-date",
            fallbackDateText = "2026-06-02",
            fallbackDate = LocalDate.parse("2026-06-03"),
        )

        assertEquals("2026-06-02", resolved.dateText)
        assertEquals(LocalDate.parse("2026-06-02"), resolved.date)
    }

    @Test
    fun `malformed occurrence and fallback date uses explicit fallback date`() {
        val resolved = resolveReminderDate(
            occurrenceDate = "legacy-date",
            fallbackDateText = "also-bad",
            fallbackDate = LocalDate.parse("2026-06-03"),
        )

        assertEquals("2026-06-03", resolved.dateText)
        assertEquals(LocalDate.parse("2026-06-03"), resolved.date)
    }
}
