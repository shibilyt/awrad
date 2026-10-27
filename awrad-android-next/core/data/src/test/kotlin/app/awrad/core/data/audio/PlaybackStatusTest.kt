package app.awrad.core.data.audio

import androidx.media3.common.Player
import app.awrad.core.domain.audio.PlaybackStatus
import kotlin.test.Test
import kotlin.test.assertEquals

class PlaybackStatusTest {

    private fun status(state: Int, playWhenReady: Boolean, isPlaying: Boolean = false, hasError: Boolean = false) =
        playbackStatusOf(state, playWhenReady, isPlaying, hasError)

    @Test
    fun `nothing loaded is idle`() {
        assertEquals(PlaybackStatus.IDLE, status(Player.STATE_IDLE, playWhenReady = false))
    }

    @Test
    fun `asked to play while buffering is loading, and playing once sound comes out`() {
        assertEquals(PlaybackStatus.LOADING, status(Player.STATE_BUFFERING, playWhenReady = true))
        assertEquals(PlaybackStatus.PLAYING, status(Player.STATE_READY, playWhenReady = true, isPlaying = true))
    }

    @Test
    fun `paused by the user, or by losing audio focus, is paused`() {
        assertEquals(PlaybackStatus.PAUSED, status(Player.STATE_READY, playWhenReady = false))
        assertEquals(PlaybackStatus.PAUSED, status(Player.STATE_BUFFERING, playWhenReady = false))
        assertEquals(PlaybackStatus.PAUSED, status(Player.STATE_READY, playWhenReady = true, isPlaying = false))
    }

    @Test
    fun `the end and errors are their own states`() {
        assertEquals(PlaybackStatus.ENDED, status(Player.STATE_ENDED, playWhenReady = true))
        assertEquals(PlaybackStatus.FAILED, status(Player.STATE_IDLE, playWhenReady = true, hasError = true))
    }
}
