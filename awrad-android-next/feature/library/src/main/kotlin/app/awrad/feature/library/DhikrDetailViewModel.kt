package app.awrad.feature.library

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.core.domain.audio.AudioPlayer
import app.awrad.core.domain.audio.AudioPlayerFactory
import app.awrad.core.domain.audio.PlaybackState
import app.awrad.core.domain.dhikr.Dhikr
import app.awrad.core.domain.dhikr.DhikrCatalogSource
import dagger.assisted.Assisted
import dagger.assisted.AssistedFactory
import dagger.assisted.AssistedInject
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * One dhikr, by its catalog [key], and its recording. The player is made on the first play, so a page that's only
 * read never loads audio, and released with the page.
 */
@HiltViewModel(assistedFactory = DhikrDetailViewModel.Factory::class)
internal class DhikrDetailViewModel @AssistedInject constructor(
    @Assisted private val key: String,
    catalogSource: DhikrCatalogSource,
    private val playerFactory: AudioPlayerFactory,
) : ViewModel() {

    private val mutableState = MutableStateFlow(DhikrDetailUiState())
    val state: StateFlow<DhikrDetailUiState> = mutableState.asStateFlow()

    private var player: AudioPlayer? = null

    init {
        viewModelScope.launch {
            val dhikr = catalogSource.catalog().dhikr(key)
            mutableState.update { it.copy(isLoading = false, dhikr = dhikr) }
        }
    }

    fun onAction(action: DhikrDetailAction) {
        when (action) {
            DhikrDetailAction.TogglePlayback -> togglePlayback()
            DhikrDetailAction.Pause -> player?.pause()
        }
    }

    private fun togglePlayback() {
        val url = mutableState.value.dhikr?.audio?.url ?: return
        if (mutableState.value.playback.isPlaying) {
            player?.pause()
        } else {
            (player ?: startPlayer()).play(url)
        }
    }

    private fun startPlayer(): AudioPlayer = playerFactory.create().also { created ->
        player = created
        viewModelScope.launch {
            created.state.collect { playback -> mutableState.update { it.copy(playback = playback) } }
        }
    }

    override fun onCleared() {
        player?.release()
        player = null
    }

    @AssistedFactory
    interface Factory {
        fun create(key: String): DhikrDetailViewModel
    }
}

/** [dhikr] is null once loaded when no dhikr has the key (a stale link). */
internal data class DhikrDetailUiState(
    val isLoading: Boolean = true,
    val dhikr: Dhikr? = null,
    val playback: PlaybackState = PlaybackState(),
)

internal sealed interface DhikrDetailAction {
    /** Play, or pause while playing. */
    data object TogglePlayback : DhikrDetailAction

    /** The page went out of sight (another page, another app): stop the sound. */
    data object Pause : DhikrDetailAction
}
