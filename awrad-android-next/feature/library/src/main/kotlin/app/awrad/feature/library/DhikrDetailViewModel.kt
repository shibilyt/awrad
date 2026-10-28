package app.awrad.feature.library

import androidx.compose.runtime.State
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.LifecycleObserver
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.audio.AudioPlayer
import app.awrad.core.domain.audio.AudioPlayerFactory
import app.awrad.core.domain.audio.PlaybackState
import app.awrad.core.domain.dhikr.Dhikr
import app.awrad.core.domain.dhikr.DhikrCatalogSource
import app.awrad.core.domain.personal.CustomDhikr
import app.awrad.core.domain.personal.CustomDhikrRepository
import app.awrad.core.domain.personal.TagRepository
import app.awrad.core.domain.personal.UserTag
import app.awrad.core.domain.personal.asDhikr
import app.awrad.core.domain.sync.ConflictChoice
import app.awrad.core.domain.sync.OpenConflict
import app.awrad.core.domain.sync.SyncService
import dagger.assisted.Assisted
import dagger.assisted.AssistedFactory
import dagger.assisted.AssistedInject
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.launch

/**
 * One dhikr by its [id], built-in or the user's own, with its tags, any conflict on it, and its recording. The
 * player is made on the first play, so a page that's only read never loads audio, and released with the page.
 */
@HiltViewModel(assistedFactory = DhikrDetailViewModel.Factory::class)
@Suppress("LongParameterList") // The ports this page reads, each a separate seam.
internal class DhikrDetailViewModel @AssistedInject constructor(
    @Assisted private val id: String,
    catalogSource: DhikrCatalogSource,
    private val customDhikrs: CustomDhikrRepository,
    private val tags: TagRepository,
    private val sync: SyncService,
    private val playerFactory: AudioPlayerFactory,
) : ViewModel() {

    private val mutableState = mutableStateOf(DhikrDetailUiState())
    val state: State<DhikrDetailUiState> = mutableState

    private val tagSheet = DhikrTagSheet(tags, viewModelScope, mutableState)
    private var player: AudioPlayer? = null

    init {
        viewModelScope.launch {
            val dhikrId = AwradId.parse(id)
            val builtIn = dhikrId?.let { catalogSource.catalog().dhikr(it) }
            val custom: Flow<CustomDhikr?> =
                if (dhikrId == null || builtIn != null) flowOf(null) else customDhikrs.dhikr(dhikrId)
            combine(custom, tags.tags, tags.tagsByDhikr, sync.conflicts) { own, allTags, byDhikr, conflicts ->
                val dhikr = builtIn ?: own?.asDhikr()
                val tagIds = dhikrId?.let { byDhikr[it] }.orEmpty()
                DhikrDetailUiState(
                    isLoading = false,
                    dhikr = dhikr,
                    custom = own,
                    tags = tagIds.mapNotNull { tagId -> allTags.firstOrNull { it.id == tagId } },
                    allTags = allTags,
                    conflict = dhikrId?.let { conflicts.firstOrNull { conflict -> conflict.key.id == it } },
                )
            }.collect { loaded ->
                mutableState.update {
                    loaded.copy(
                        playback = it.playback,
                        sheet = it.sheet,
                        isDeleteConfirmOpen = it.isDeleteConfirmOpen,
                        isDeleted = it.isDeleted,
                    )
                }
            }
        }
    }

    fun onAction(action: DhikrDetailAction) {
        when (action) {
            DhikrDetailAction.TogglePlayback -> togglePlayback()
            DhikrDetailAction.Pause -> player?.pause()
            DhikrDetailAction.AskDelete -> mutableState.update { it.copy(isDeleteConfirmOpen = true) }
            DhikrDetailAction.CancelDelete -> mutableState.update { it.copy(isDeleteConfirmOpen = false) }
            DhikrDetailAction.ConfirmDelete -> delete()
            is DhikrDetailAction.Resolve -> resolve(action.choice)
            is DhikrDetailAction.Tags -> tagSheet.onAction(action.action, AwradId.parse(id))
        }
    }

    private fun delete() {
        val custom = mutableState.value.custom ?: return
        mutableState.update { it.copy(isDeleteConfirmOpen = false) }
        player?.pause()
        viewModelScope.launch {
            customDhikrs.delete(custom.id)
            mutableState.update { it.copy(isDeleted = true) }
        }
    }

    private fun resolve(choice: ConflictChoice) {
        val conflict = mutableState.value.conflict ?: return
        viewModelScope.launch { sync.resolve(conflict.key, choice) }
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
        fun create(id: String): DhikrDetailViewModel
    }
}

/**
 * [dhikr] is null once loaded when no dhikr has the ID (a stale link, or deleted). [custom] is set for the
 * user's own dhikr, which can be edited and deleted. [tags] are this dhikr's, in its order; [conflict] is open
 * on the dhikr or its tags. [isDeleted] means it's gone and the page should close.
 */
internal data class DhikrDetailUiState(
    val isLoading: Boolean = true,
    val dhikr: Dhikr? = null,
    val custom: CustomDhikr? = null,
    val tags: List<UserTag> = emptyList(),
    val allTags: List<UserTag> = emptyList(),
    val conflict: OpenConflict? = null,
    val playback: PlaybackState = PlaybackState(),
    val sheet: TagSheetState? = null,
    val isDeleteConfirmOpen: Boolean = false,
    val isDeleted: Boolean = false,
)

internal sealed interface DhikrDetailAction {
    /** Play, or pause while playing. */
    data object TogglePlayback : DhikrDetailAction

    /** The page went out of sight (another page, another app) or away: stop the sound. */
    data object Pause : DhikrDetailAction

    data object AskDelete : DhikrDetailAction

    data object CancelDelete : DhikrDetailAction

    data object ConfirmDelete : DhikrDetailAction

    /** Keep mine or Use theirs on the open conflict. */
    data class Resolve(val choice: ConflictChoice) : DhikrDetailAction

    /** Something in the "Manage tags" sheet. */
    data class Tags(val action: TagSheetAction) : DhikrDetailAction
}

/**
 * Sends [DhikrDetailAction.Pause] when the page's lifecycle stops: another page opens on top, or the app goes to
 * the background (Home, another app, the screen off).
 */
internal fun pauseOnStop(onAction: (DhikrDetailAction) -> Unit): LifecycleObserver =
    LifecycleEventObserver { _, event -> if (event == Lifecycle.Event.ON_STOP) onAction(DhikrDetailAction.Pause) }
