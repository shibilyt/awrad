package app.awrad.core.data.audio

import android.content.Context
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import app.awrad.core.domain.audio.AudioPlayer
import app.awrad.core.domain.audio.AudioPlayerFactory
import app.awrad.core.domain.audio.PlaybackState
import app.awrad.core.domain.audio.PlaybackStatus
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Job
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import javax.inject.Inject

/** Makes an [ExoAudioPlayer] per screen. */
internal class ExoAudioPlayerFactory @Inject constructor(
    @ApplicationContext private val context: Context,
) : AudioPlayerFactory {
    override fun create(): AudioPlayer = ExoAudioPlayer(context)
}

/**
 * Streams a recording with Media3's ExoPlayer. It holds audio focus as speech (pausing when another app plays, or
 * when headphones are unplugged) and reports its position every [TICK_MS] while playing. Use it from the main
 * thread, as ExoPlayer requires, and [release] it when the screen goes.
 */
internal class ExoAudioPlayer(context: Context) : AudioPlayer {

    private val player: ExoPlayer = ExoPlayer.Builder(context)
        .setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(C.USAGE_MEDIA)
                .setContentType(C.AUDIO_CONTENT_TYPE_SPEECH)
                .build(),
            // handleAudioFocus
            true,
        )
        .setHandleAudioBecomingNoisy(true)
        .build()
    private val scope = MainScope()
    private val mutableState = MutableStateFlow(PlaybackState())
    private var loadedUrl: String? = null
    private var ticker: Job? = null

    private val listener = object : Player.Listener {
        override fun onEvents(player: Player, events: Player.Events) = publish()
    }

    override val state: StateFlow<PlaybackState> = mutableState.asStateFlow()

    init {
        player.addListener(listener)
    }

    override fun play(url: String) {
        when {
            url != loadedUrl -> {
                loadedUrl = url
                player.setMediaItem(MediaItem.fromUri(url))
                player.prepare()
            }
            // After an error the player is idle again: preparing retries.
            player.playbackState == Player.STATE_IDLE -> player.prepare()
            player.playbackState == Player.STATE_ENDED -> player.seekTo(0)
        }
        player.play()
        publish()
    }

    override fun pause() {
        player.pause()
        publish()
    }

    override fun release() {
        scope.cancel()
        player.removeListener(listener)
        player.release()
    }

    private fun publish() {
        val status = playbackStatusOf(
            playerState = player.playbackState,
            playWhenReady = player.playWhenReady,
            isPlaying = player.isPlaying,
            hasError = player.playerError != null,
        )
        mutableState.value = PlaybackState(
            status = status,
            positionMs = player.currentPosition,
            durationMs = player.duration.takeIf { it != C.TIME_UNSET },
        )
        if (status == PlaybackStatus.PLAYING) startTicker() else ticker?.cancel()
    }

    private fun startTicker() {
        if (ticker?.isActive == true) return
        ticker = scope.launch {
            while (isActive) {
                delay(TICK_MS)
                publish()
            }
        }
    }

    private companion object {
        const val TICK_MS = 250L
    }
}

/**
 * The [PlaybackStatus] for ExoPlayer's state: [playerState] is a `Player.STATE_*`, [playWhenReady] whether it
 * was asked to play, [isPlaying] whether sound is coming out (false while audio focus is lost), [hasError] whether
 * it failed.
 */
internal fun playbackStatusOf(
    playerState: Int,
    playWhenReady: Boolean,
    isPlaying: Boolean,
    hasError: Boolean,
): PlaybackStatus = when {
    hasError -> PlaybackStatus.FAILED
    playerState == Player.STATE_IDLE -> PlaybackStatus.IDLE
    playerState == Player.STATE_ENDED -> PlaybackStatus.ENDED
    !playWhenReady -> PlaybackStatus.PAUSED
    playerState == Player.STATE_BUFFERING -> PlaybackStatus.LOADING
    isPlaying -> PlaybackStatus.PLAYING
    else -> PlaybackStatus.PAUSED
}
