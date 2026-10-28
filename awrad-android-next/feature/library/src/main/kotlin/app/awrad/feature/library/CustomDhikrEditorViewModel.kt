package app.awrad.feature.library

import androidx.compose.runtime.State
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.audio.AudioPlayer
import app.awrad.core.domain.audio.AudioPlayerFactory
import app.awrad.core.domain.personal.AudioImport
import app.awrad.core.domain.personal.CustomDhikrError
import app.awrad.core.domain.personal.CustomDhikrRepository
import app.awrad.core.domain.personal.TagRepository
import dagger.assisted.Assisted
import dagger.assisted.AssistedFactory
import dagger.assisted.AssistedInject
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

/**
 * The custom dhikr editor: a new dhikr (with a new UUIDv7) or the one with [dhikrId]. Saving checks the shared
 * validity rules, then writes the dhikr and its tags; a recording imported but not saved is deleted when the
 * editor goes away. Nothing here needs an account or the network.
 */
@HiltViewModel(assistedFactory = CustomDhikrEditorViewModel.Factory::class)
internal class CustomDhikrEditorViewModel @AssistedInject constructor(
    @Assisted private val dhikrId: String?,
    private val customDhikrs: CustomDhikrRepository,
    private val tags: TagRepository,
    private val playerFactory: AudioPlayerFactory,
) : ViewModel() {

    private val id: AwradId = dhikrId?.let(AwradId::parse) ?: AwradId.random()
    private val mutableState = mutableStateOf(EditorUiState(isNew = dhikrId == null))
    val state: State<EditorUiState> = mutableState

    private var player: AudioPlayer? = null

    /** Imported recordings not (yet) saved, to delete if the editor is left. */
    private val unsaved = mutableListOf<String>()

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
                player?.pause()
                edit { copy(audio = null, audioError = null) }
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
        mutableState.update { it.change().copy(problems = emptySet()) }
    }

    private fun importAudio(sourceUri: String) {
        viewModelScope.launch {
            when (val imported = customDhikrs.importAudio(sourceUri)) {
                is AudioImport.Imported -> {
                    player?.pause()
                    unsaved += imported.localUri
                    val field = AudioField(imported.localUri, isNew = true)
                    mutableState.update { it.copy(audio = field, audioError = null) }
                }
                is AudioImport.Failed -> mutableState.update { it.copy(audioError = imported.error) }
            }
        }
    }

    private fun togglePlayback() {
        val uri = mutableState.value.audio?.localUri ?: return
        if (mutableState.value.playback.isPlaying) {
            player?.pause()
        } else {
            (player ?: startPlayer()).play(uri)
        }
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
                null -> emptySet()
                is CustomDhikrError.Invalid -> problemsOf(error.errors, hasQuran = !current.quran.isEmpty)
                CustomDhikrError.LimitReached -> setOf(EditorProblem.LIMIT_REACHED)
                CustomDhikrError.NotFound -> setOf(EditorProblem.NOT_SAVED)
            }
            if (problems.isEmpty()) {
                tags.setTags(id, current.selectedTags)
                dhikr.audio?.localUri?.let { unsaved.remove(it) }
            }
            mutableState.update { it.copy(isSaving = false, problems = problems, isDone = problems.isEmpty()) }
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
