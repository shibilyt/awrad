package app.awrad.awrad_dhikrgoalstracker.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CustomDhikrAudioLimitsTest {

    @Test
    fun maxBytesIsStrictlyUnderTenMillion() {
        assertEquals(10_000_000L, CustomDhikrAudioLimits.MAX_BYTES_EXCLUSIVE)
        assertTrue(CustomDhikrAudioLimits.isByteSizeAllowed(9_999_999L))
        assertFalse(CustomDhikrAudioLimits.isByteSizeAllowed(10_000_000L))
        assertFalse(CustomDhikrAudioLimits.isByteSizeAllowed(10_000_001L))
    }

    @Test
    fun maxDurationIsTenMinutesInclusive() {
        assertEquals(10 * 60 * 1000L, CustomDhikrAudioLimits.MAX_DURATION_MS)
        assertTrue(CustomDhikrAudioLimits.isDurationAllowed(10 * 60 * 1000L))
        assertFalse(CustomDhikrAudioLimits.isDurationAllowed(10 * 60 * 1000L + 1L))
    }

    @Test
    fun acceptsInteroperablePlaybackMimeTypesOnly() {
        assertTrue(CustomDhikrAudioLimits.isMimeTypeAllowed("audio/mp4"))
        assertTrue(CustomDhikrAudioLimits.isMimeTypeAllowed("audio/mpeg"))
        assertTrue(CustomDhikrAudioLimits.isMimeTypeAllowed("audio/wav"))
        assertTrue(CustomDhikrAudioLimits.isMimeTypeAllowed("audio/x-wav"))
        assertTrue(CustomDhikrAudioLimits.isMimeTypeAllowed("audio/aac"))
        assertFalse(CustomDhikrAudioLimits.isMimeTypeAllowed("audio/ogg"))
        assertFalse(CustomDhikrAudioLimits.isMimeTypeAllowed("video/mp4"))
        assertFalse(CustomDhikrAudioLimits.isMimeTypeAllowed(null))
    }
}
