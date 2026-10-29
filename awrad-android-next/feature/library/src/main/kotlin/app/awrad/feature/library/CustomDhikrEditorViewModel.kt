package app.awrad.feature.library

import androidx.compose.runtime.State
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.audio.AudioPlayer
import app.awrad.core.domain.audio.AudioPlayerFactory
import app.awrad.core.domain.audio.PlaybackStatus
import app.awrad.core.domain.personal.AudioImport
import app.awrad.core.domain.personal.CustomAudioService
import app.awrad.core.domain.personal.CustomDhikrError
import app.awrad.core.domain.personal.CustomDhikrRepository
import app.awrad.core.domain.personal.RecordingPlayback
import app.awrad.core.domain.personal.TagRepository
import dagger.assisted.Assisted
import dagger.assisted.AssistedFactory
import dagger.assisted.AssistedInject
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

/**
 * The custom dhikr editor: a new dhikr (with a new UUIDv7) or the one with [dhikrId]. Saving checks the shared
 * validity rules, then writes the dhikr and its tags; a recording imported but not saved is deleted when the
 * editor goes away. Nothing here needs an account or the network, except playing a recording that's only in the
 * account, which downloads it first; the card also says where the saved recording's upload stands.
 */
@HiltViewModel(assistedFactory = CustomDhikrEditorViewModel.Factory::class)
internal class CustomDhikrEditorViewModel @AssistedInject constructor(
    @Assisted private val dhikrId: String?,
    private val customDhikrs: CustomDhikrRepository,
    private val tags: TagRepository,
    private val playerFactory: AudioPlayerFactory,
    private val audio: CustomAudioService,
) : ViewModel() {

    private val id: AwradId = dhikrId?.let(AwradId::parse) ?: AwradId.random()
    private val mutableState = mutableStateOf(EditorUiState(isNew = dhikrId == null))
    val state: State<EditorUiState> = mutableState

    private var player: AudioPlayer? = null

    /** Imported recordings not (yet) saved, to delete if the editor is left. */
    private val unsaved = mutableListOf<String>()

    /** The uploaded recording's file once downloaded here, for later plays; the dhikr's own field is unchanged. */
    private var downloaded: String? = null
    private var download: Job? = null

    init {
        viewModelScope.launch {
            val existing = if (dhikrId != null) customDhikrs.dhikr(id).first() else null
            val tagIds = tags.tagsByDhikr.first()[id].orEmpty()
            mutableState.update { state ->
                (existing?.let { state.loaded(it) } ?: state.copy(isLoading = false)).copy(selectedTags = tagIds)
            }
        }
        viewModelScope.launch {
            tags.tags.collect { list -> mutableState.update { it.copy(tags = list) } }
        }
        viewModelScope.launch {
            audio.upload(id).collect { upload -> mutableState.update { it.copy(upload = upload) } }
        }
    }

    @Suppress("CyclomaticComplexMethod") // One branch per field of the form.
    fun onAction(action: EditorAction) {
        when (action) {
            is EditorAction.KindChanged -> edit { copy(kind = action.kind) }
            is EditorAction.ArabicChanged -> edit { copy(arabic = action.text) }
            is EditorAction.LanguageShown -> mutableState.update { it.copy(shownLanguage = action.language) }
            is EditorAction.TitleChanged -> edit { copy(titles = titles.with(shownLanguage, action.text)) }
            is EditorAction.TransliterationChanged ->
                edit { copy(transliterations = transliterations.with(shownLanguage, action.text)) }
            is EditorAction.TranslationChanged ->
                edit { copy(translations = translations.with(shownLanguage, action.text)) }
            is EditorAction.QuranChanged -> edit { copy(quran = action.quran) }
            EditorAction.AddReference -> edit { copy(otherReferences = otherReferences + "") }
            is EditorAction.ReferenceChanged -> edit {
                copy(otherReferences = otherReferences.toMutableList().also { it[action.index] = action.text })
            }
            is EditorAction.RemoveReference -> edit {
                copy(otherReferences = otherReferences.filterIndexed { i, _ -> i != action.index })
            }
            is EditorAction.RemoveKeptReference ->
                edit { copy(kept = kept.filterIndexed { i, _ -> i != action.index }) }
            is EditorAction.ImportAudio -> importAudio(action.sourceUri)
            EditorAction.RemoveAudio -> {
                stopAudio()
                edit { copy(audio = null, audioError = null, downloadError = null) }
            }
            EditorAction.TogglePlayback -> togglePlayback()
            is EditorAction.TagToggled -> mutableState.update {
                val tag = action.tagId
                it.copy(selectedTags = if (tag in it.selectedTags) it.selectedTags - tag else it.selectedTags + tag)
            }
            EditorAction.Save -> save()
            EditorAction.AskDelete -> mutableState.update { it.copy(isDeleteConfirmOpen = true) }
            EditorAction.CancelDelete -> mutableState.update { it.copy(isDeleteConfirmOpen = false) }
            EditorAction.ConfirmDelete -> delete()
        }
    }

    /** A change to the form: the last save's problems no longer apply. */
    private fun edit(change: EditorUiState.() -> EditorUiState) {
        mutableState.update { it.change().copy(problems = emptyMap()) }
    }

    private fun importAudio(sourceUri: String) {
        viewModelScope.launch {
            when (val imported = customDhikrs.importAudio(sourceUri)) {
                is AudioImport.Imported -> {
                    stopAudio()
                    unsaved += imported.localUri
                    val field = AudioField(imported.localUri, isNew = true)
                    mutableState.update { it.copy(audio = field, audioError = null, downloadError = null) }
                }
                is AudioImport.Failed -> mutableState.update { it.copy(audioError = imported.error) }
            }
        }
    }

    /**
     * Play or pause. A recording that isn't on this phone is downloaded first (the button spins meanwhile); pausing
     * then stops the download.
     */
    private fun togglePlayback() {
        val field = mutableState.value.audio?.takeIf { it.isPlayable } ?: return
        when {
            download?.isActive == true -> cancelDownload()
            mutableState.value.playback.isPlaying -> player?.pause()
            else -> field.localUri?.let(::play) ?: downloaded?.let(::play) ?: downloadAndPlay()
        }
    }

    private fun play(uri: String) {
        (player ?: startPlayer()).play(uri)
    }

    private fun downloadAndPlay() {
        mutableState.update {
            it.copy(playback = it.playback.copy(status = PlaybackStatus.LOADING), downloadError = null)
        }
        download = viewModelScope.launch {
            when (val playable = audio.playable(id)) {
                is RecordingPlayback.Ready -> {
                    downloaded = playable.localUri
                    play(playable.localUri)
                }
                is RecordingPlayback.Failed -> mutableState.update {
                    val failed = it.playback.copy(status = PlaybackStatus.FAILED)
                    it.copy(playback = failed, downloadError = playable.reason)
                }
            }
        }
    }

    /** The recording is replaced or removed: stop it, and forget the downloaded one. */
    private fun stopAudio() {
        if (download?.isActive == true) cancelDownload()
        player?.pause()
        downloaded = null
    }

    private fun cancelDownload() {
        download?.cancel()
        mutableState.update { it.copy(playback = it.playback.copy(status = PlaybackStatus.IDLE)) }
    }

    private fun startPlayer(): AudioPlayer = playerFactory.create().also { created ->
        player = created
        viewModelScope.launch {
            created.state.collect { playback -> mutableState.update { it.copy(playback = playback) } }
        }
    }

    private fun save() {
        val current = mutableState.value
        if (current.isSaving) return
        val dhikr = current.toDhikr(id)
        mutableState.update { it.copy(isSaving = true) }
        viewModelScope.launch {
            val problems = when (val error = customDhikrs.save(dhikr)) {
                null -> emptyMap()
                is CustomDhikrError.Invalid -> current.problemsOf(error.errors)
                CustomDhikrError.LimitReached -> mapOf(ProblemSpot.SUMMARY to EditorProblem.LIMIT_REACHED)
                CustomDhikrError.NotFound -> mapOf(ProblemSpot.SUMMARY to EditorProblem.NOT_SAVED)
            }
            if (problems.isEmpty()) {
                tags.setTags(id, current.selectedTags)
                dhikr.audio?.localUri?.let { unsaved.remove(it) }
            }
            mutableState.update {
                it.copy(
                    isSaving = false,
                    problems = problems,
                    failedSaves = if (problems.isEmpty()) it.failedSaves else it.failedSaves + 1,
                    isDone = problems.isEmpty(),
                )
            }
        }
    }

    private fun delete() {
        mutableState.update { it.copy(isDeleteConfirmOpen = false) }
        viewModelScope.launch {
            customDhikrs.delete(id)
            mutableState.update { it.copy(isDone = true) }
        }
    }

    override fun onCleared() {
        player?.release()
        player = null
        // The ViewModel's scope is gone; the repository's own work doesn't need it.
        val leftover = unsaved.toList()
        if (leftover.isNotEmpty()) {
            kotlinx.coroutines.MainScope().launch { leftover.forEach { customDhikrs.discardAudio(it) } }
        }
    }

    @AssistedFactory
    interface Factory {
        fun create(dhikrId: String?): CustomDhikrEditorViewModel
    }
}
