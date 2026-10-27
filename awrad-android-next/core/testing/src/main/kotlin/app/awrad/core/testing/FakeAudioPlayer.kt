package app.awrad.core.testing

import app.awrad.core.domain.audio.AudioPlayer
import app.awrad.core.domain.audio.AudioPlayerFactory
import app.awrad.core.domain.audio.PlaybackState
import app.awrad.core.domain.audio.PlaybackStatus
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * A player that only records calls. [play] goes to `LOADING`, as the real one does while it connects; tests move
 * it on with [emit]. Calls after [release] fail, as they would on the real player.
 */
public class FakeAudioPlayer : AudioPlayer {
    private val mutableState = MutableStateFlow(PlaybackState())
    override val state: StateFlow<PlaybackState> = mutableState

    public val played: MutableList<String> = mutableListOf()
    public var pauses: Int = 0
        private set
    public var isReleased: Boolean = false
        private set

    override fun play(url: String) {
        check(!isReleased) { "play after release" }
        played += url
        mutableState.value = mutableState.value.copy(status = PlaybackStatus.LOADING)
    }

    override fun pause() {
        check(!isReleased) { "pause after release" }
        pauses++
        if (mutableState.value.isPlaying) mutableState.value = mutableState.value.copy(status = PlaybackStatus.PAUSED)
    }

    override fun release() {
        isReleased = true
    }

    /** Moves the player to [state], as the real player reports progress. */
    public fun emit(state: PlaybackState) {
        mutableState.value = state
    }
}

/** Hands out [FakeAudioPlayer]s and keeps them for assertions. */
public class FakeAudioPlayerFactory : AudioPlayerFactory {
    public val players: MutableList<FakeAudioPlayer> = mutableListOf()

    override fun create(): AudioPlayer = FakeAudioPlayer().also { players += it }
}
