package app.awrad.awrad_dhikrgoalstracker.service

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId

data class PreviewPlaybackState(
    val dhikrId: AwradId? = null,
    val isPlaying: Boolean = false,
    val currentPositionMs: Long = 0,
    val durationMs: Long = 0,
) {
    val progress: Float
        get() = if (durationMs > 0) currentPositionMs.toFloat() / durationMs else 0f
}

/**
 * Single app-wide audio player for dhikr preview playback.
 * Only one dhikr can play at a time. Playback does not loop.
 *
 * Uses [onIsPlayingChanged] as the primary callback (recommended by Media3 docs)
 * combined with [playbackState] check to reliably detect completion.
 */
@Singleton
class AudioPreviewPlayer @Inject constructor(
    @ApplicationContext private val context: Context,
    private val audioDownloadManager: AudioDownloadManager,
) {
    private val _state = MutableStateFlow(PreviewPlaybackState())
    val state: StateFlow<PreviewPlaybackState> = _state.asStateFlow()

    private var player: ExoPlayer? = null
    private var currentDhikrId: AwradId? = null
    private val handler = Handler(Looper.getMainLooper())

    private val progressRunnable = object : Runnable {
        override fun run() {
            val p = player ?: return
            if (_state.value.isPlaying) {
                _state.value = _state.value.copy(
                    currentPositionMs = p.currentPosition,
                    durationMs = p.duration.coerceAtLeast(0),
                )
                handler.postDelayed(this, 200)
            }
        }
    }

    private val playerListener = object : Player.Listener {
        override fun onIsPlayingChanged(isPlaying: Boolean) {
            if (isPlaying) {
                // Playback is active
                _state.value = _state.value.copy(isPlaying = true)
                handler.removeCallbacks(progressRunnable)
                handler.post(progressRunnable)
            } else {
                // Playback stopped — check why
                val p = player ?: return
                handler.removeCallbacks(progressRunnable)

                when (p.playbackState) {
                    Player.STATE_ENDED -> {
                        // Finished naturally: reset everything
                        resetPlayer()
                    }
                    Player.STATE_IDLE -> {
                        // Player was stopped or errored
                        resetPlayer()
                    }
                    else -> {
                        // Paused or buffering — keep state but mark not playing
                        _state.value = _state.value.copy(isPlaying = false)
                    }
                }
            }
        }
    }

    fun toggle(dhikrId: AwradId, audioUrl: String?, audioFileName: String?) {
        val p = player

        // Pause if currently playing this dhikr
        if (currentDhikrId == dhikrId && p != null && p.isPlaying) {
            p.pause()
            return
        }

        // Resume if paused on this dhikr
        if (currentDhikrId == dhikrId && p != null && p.playbackState == Player.STATE_READY) {
            p.play()
            return
        }

        // Start fresh playback
        val uri = resolveUri(audioUrl, audioFileName) ?: return
        releasePlayer()

        currentDhikrId = dhikrId
        val exo = ExoPlayer.Builder(context).build()
        exo.repeatMode = Player.REPEAT_MODE_OFF
        exo.addListener(playerListener)
        exo.setMediaItem(MediaItem.fromUri(uri))
        exo.prepare()
        exo.play()

        player = exo
        _state.value = PreviewPlaybackState(dhikrId = dhikrId, isPlaying = true)
    }

    fun stop() {
        releasePlayer()
        resetState()
    }

    private fun resetPlayer() {
        _state.value = PreviewPlaybackState()
        currentDhikrId = null
        // Release on next handler loop to avoid releasing during callback
        val p = player
        player = null
        if (p != null) {
            handler.post {
                p.removeListener(playerListener)
                p.release()
            }
        }
    }

    private fun releasePlayer() {
        handler.removeCallbacks(progressRunnable)
        val p = player
        player = null
        currentDhikrId = null
        if (p != null) {
            p.removeListener(playerListener)
            p.stop()
            p.release()
        }
    }

    private fun resetState() {
        _state.value = PreviewPlaybackState()
    }

    private fun resolveUri(audioUrl: String?, audioFileName: String?): String? {
        if (audioFileName != null) {
            val localPath = audioDownloadManager.getAudioFilePath(audioFileName)
            if (localPath != null) return localPath
        }
        return audioUrl
    }
}
