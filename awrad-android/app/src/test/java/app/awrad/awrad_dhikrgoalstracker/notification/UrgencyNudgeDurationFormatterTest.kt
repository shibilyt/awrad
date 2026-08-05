package app.awrad.awrad_dhikrgoalstracker.notification

import app.awrad.awrad_dhikrgoalstracker.R
import org.junit.Assert.assertEquals
import org.junit.Test

class UrgencyNudgeDurationFormatterTest {
    @Test
    fun `formats conservative concise duration boundaries`() {
        assertEquals("under-minute", format(59_999L))
        assertEquals("1m", format(60_000L))
        assertEquals("59m", format(59 * 60_000L))
        assertEquals("1h", format(60 * 60_000L))
        assertEquals("2h 30m", format(150 * 60_000L))
        assertEquals("1d", format(24 * 60 * 60_000L))
        assertEquals(
            "106751991167d 7h",
            format(Long.MAX_VALUE),
        )
    }

    private fun format(millis: Long): String = UrgencyNudgeDurationFormatter.format(millis) { id, args ->
        when (id) {
            R.string.notif_urgency_duration_less_than_minute -> "under-minute"
            R.string.notif_urgency_duration_minutes -> "${args[0]}m"
            R.string.notif_urgency_duration_hours -> "${args[0]}h"
            R.string.notif_urgency_duration_days -> "${args[0]}d"
            R.string.notif_urgency_duration_hours_minutes -> "${args[0]}h ${args[1]}m"
            R.string.notif_urgency_duration_days_hours -> "${args[0]}d ${args[1]}h"
            else -> error("unexpected resource $id")
        }
    }
}
