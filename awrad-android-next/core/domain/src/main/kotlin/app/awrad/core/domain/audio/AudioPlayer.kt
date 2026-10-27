package app.awrad.core.domain.audio

import kotlinx.coroutines.flow.StateFlow

/** Where a player is. */
public enum class PlaybackStatus {
    /** Nothing loaded yet. */
    IDLE,

    /** Asked to play, waiting for audio (connecting, buffering). */
    LOADING,
    PLAYING,
    PAUSED,

    /** Played to the end; playing again starts over. */
    ENDED,

    /** The audio couldn't be loaded or played (no network, a bad file). Playing again retries. */
    FAILED,
}

/** A player's [status], how far it is ([positionMs]) and the recording's length once known ([durationMs]). */
public data class PlaybackState(
    val status: PlaybackStatus = PlaybackStatus.IDLE,
    val positionMs: Long = 0,
    val durationMs: Long? = null,
) {
    /** Playing, or about to: the play/pause control shows pause. */
    val isPlaying: Boolean get() = status == PlaybackStatus.PLAYING || status == PlaybackStatus.LOADING

    /** How much has played, from 0 to 1, or null while the length is unknown. */
    val progress: Float?
        get() = durationMs?.takeIf { it > 0 }?.let { (positionMs.toFloat() / it).coerceIn(0f, 1f) }
}

/**
 * Port: plays one recording at a time, streamed from its URL. Each screen that plays audio creates its own with
 * [AudioPlayerFactory] and must [release] it when it goes away.
 */
public interface AudioPlayer {
    /** Where the player is; the position updates while it plays. */
    public val state: StateFlow<PlaybackState>

    /** Plays [url]: resumes it if it's the recording already loaded, else loads it and plays from the start. */
    public fun play(url: String)

    public fun pause()

    /** Stops and frees the player; it can't be used afterwards. */
    public fun release()
}

/** Port: makes an [AudioPlayer]. */
public fun interface AudioPlayerFactory {
    public fun create(): AudioPlayer
}
