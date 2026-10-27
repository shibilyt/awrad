package app.awrad.core.domain.audio

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class PlaybackStateTest {

    @Test
    fun `loading and playing show pause, everything else play`() {
        assertTrue(PlaybackState(PlaybackStatus.LOADING).isPlaying)
        assertTrue(PlaybackState(PlaybackStatus.PLAYING).isPlaying)
        listOf(PlaybackStatus.IDLE, PlaybackStatus.PAUSED, PlaybackStatus.ENDED, PlaybackStatus.FAILED).forEach {
            assertFalse(PlaybackState(it).isPlaying, it.name)
        }
    }

    @Test
    fun `progress is the share played once the length is known`() {
        assertNull(PlaybackState(PlaybackStatus.PLAYING, positionMs = 500).progress)
        assertNull(PlaybackState(PlaybackStatus.PLAYING, positionMs = 500, durationMs = 0).progress)
        assertEquals(0.25f, PlaybackState(PlaybackStatus.PLAYING, positionMs = 500, durationMs = 2_000).progress)
        assertEquals(1f, PlaybackState(PlaybackStatus.ENDED, positionMs = 2_100, durationMs = 2_000).progress)
    }
}
