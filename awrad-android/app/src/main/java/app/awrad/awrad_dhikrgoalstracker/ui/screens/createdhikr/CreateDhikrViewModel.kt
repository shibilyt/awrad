package app.awrad.awrad_dhikrgoalstracker.ui.screens.createdhikr

import android.content.Context
import android.net.Uri
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.UserTag
import app.awrad.awrad_dhikrgoalstracker.data.repository.DhikrRepository
import app.awrad.awrad_dhikrgoalstracker.domain.CustomDhikrFactory
import app.awrad.awrad_dhikrgoalstracker.service.CustomDhikrAudioException
import app.awrad.awrad_dhikrgoalstracker.service.CustomDhikrAudioStore
import app.awrad.awrad_dhikrgoalstracker.service.MediaMetadataCustomDhikrAudioProbe
import app.awrad.awrad_dhikrgoalstracker.service.OwnedAudioAvailability
import app.awrad.awrad_dhikrgoalstracker.service.StagedOwnedAudio
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import java.util.UUID
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class CreateDhikrUiState(
    val editingDhikrId: AwradId? = null,
    val title: String = "",
    val arabic: String = "",
    val transliteration: String = "",
    val translation: String = "",
    val category: DhikrCategory = DhikrCategory.GENERAL,
    val audioCountPerPlay: Int = 1,
    val selectedTagIds: Set<AwradId> = emptySet(),
    val ownedAudioName: String? = null,
    val ownedAudioMissing: Boolean = false,
    val stagedAudio: StagedOwnedAudio? = null,
    /** True when a persisted owned-audio row/file exists for the editing dhikr. */
    val persistedOwnedAudioPresent: Boolean = false,
    val removeOwnedAudioPending: Boolean = false,
    val audioError: String? = null,
    val saveError: String? = null,
    val isSaving: Boolean = false,
    val isSaved: Boolean = false,
    val isDeleted: Boolean = false,
) {
    val isEditing: Boolean get() = editingDhikrId != null
}

@HiltViewModel
class CreateDhikrViewModel @Inject constructor(
    private val dhikrRepository: DhikrRepository,
    private val audioStore: CustomDhikrAudioStore,
    private val audioProbe: MediaMetadataCustomDhikrAudioProbe,
    @ApplicationContext private val context: Context,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val _uiState = MutableStateFlow(CreateDhikrUiState())
    val uiState: StateFlow<CreateDhikrUiState> = _uiState.asStateFlow()

    val availableTags: StateFlow<List<UserTag>> = dhikrRepository.observeUserTags()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    val isValid: Boolean
        get() = _uiState.value.arabic.isNotBlank()

    init {
        val editId = savedStateHandle.get<String>("dhikrId")
            ?.let { value -> runCatching { UUID.fromString(value) }.getOrNull() }
        if (editId != null) {
            viewModelScope.launch { loadForEdit(editId) }
        }
    }

    private suspend fun loadForEdit(id: AwradId) {
        val dhikr = dhikrRepository.getDhikrById(id) ?: return
        if (!dhikr.isCustom) return
        val owned = dhikrRepository.getOwnedAudio(id)
        val missing = owned != null &&
            dhikrRepository.ownedAudioAvailability(id) == OwnedAudioAvailability.MISSING
        val tags = dhikrRepository.observeTagIdsForDhikr(id)
        _uiState.update {
            it.copy(
                editingDhikrId = id,
                title = dhikr.title,
                arabic = dhikr.arabic,
                transliteration = dhikr.transliteration,
                translation = dhikr.translation,
                category = dhikr.category,
                audioCountPerPlay = dhikr.audioCountPerPlay,
                ownedAudioName = owned?.relativeFileName,
                ownedAudioMissing = missing,
                persistedOwnedAudioPresent = owned != null,
            )
        }
        viewModelScope.launch {
            tags.collect { ids -> _uiState.update { state -> state.copy(selectedTagIds = ids) } }
        }
    }

    fun onTitleChanged(value: String) {
        _uiState.update { it.copy(title = value) }
    }

    fun onArabicChanged(value: String) {
        _uiState.update { it.copy(arabic = value) }
    }

    fun onTransliterationChanged(value: String) {
        _uiState.update { it.copy(transliteration = value) }
    }

    fun onTranslationChanged(value: String) {
        _uiState.update { it.copy(translation = value) }
    }

    fun onCategoryChanged(category: DhikrCategory) {
        _uiState.update { it.copy(category = category) }
    }

    fun onAudioCountPerPlayChanged(value: Int) {
        _uiState.update {
            it.copy(audioCountPerPlay = CreateDhikrEditorState.normalizeCountsPerPlay(value))
        }
    }

    fun onTagSelectionChanged(tagIds: Set<AwradId>) {
        _uiState.update { it.copy(selectedTagIds = tagIds) }
    }

    fun toggleTag(tagId: AwradId) {
        _uiState.update {
            it.copy(selectedTagIds = CreateDhikrEditorState.toggleTag(it.selectedTagIds, tagId))
        }
    }

    fun createAndSelectTag(rawName: String) {
        viewModelScope.launch {
            val selected = _uiState.value.selectedTagIds
            if (!app.awrad.awrad_dhikrgoalstracker.data.repository.CustomDhikrMutationPolicy
                    .canAssignTag(selected.size)
            ) {
                _uiState.update { it.copy(saveError = "too_many_tags") }
                return@launch
            }
            val created = dhikrRepository.createUserTag(rawName) ?: return@launch
            _uiState.update {
                it.copy(selectedTagIds = it.selectedTagIds + created.id, saveError = null)
            }
        }
    }

    fun importAudio(uri: Uri) {
        viewModelScope.launch {
            val previousStaged = _uiState.value.stagedAudio
            try {
                val mime = context.contentResolver.getType(uri)
                val declaredSize = context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                    val index = cursor.getColumnIndex(android.provider.OpenableColumns.SIZE)
                    if (cursor.moveToFirst() && index >= 0 && !cursor.isNull(index)) {
                        cursor.getLong(index)
                    } else {
                        null
                    }
                }
                if (declaredSize != null &&
                    !app.awrad.awrad_dhikrgoalstracker.service.CustomDhikrAudioLimits
                        .isByteSizeAllowed(declaredSize)
                ) {
                    throw CustomDhikrAudioException(CustomDhikrAudioException.Reason.SIZE)
                }
                val input = context.contentResolver.openInputStream(uri)
                    ?: throw CustomDhikrAudioException(CustomDhikrAudioException.Reason.IO)
                val staged = input.use { stream ->
                    audioStore.stageImport(
                        input = stream,
                        declaredByteSize = declaredSize ?: 0L,
                        mimeType = mime,
                        probe = audioProbe,
                    )
                }
                val decision = CreateDhikrAudioDraftPolicy.onReplacementStaged(
                    previousStaged = previousStaged,
                    newStaged = staged,
                )
                decision.discardStaged?.let(audioStore::discardStaged)
                _uiState.update {
                    it.copy(
                        stagedAudio = decision.keepStaged,
                        ownedAudioName = staged.relativeFileName,
                        ownedAudioMissing = false,
                        removeOwnedAudioPending = decision.removeOwnedAudioPending,
                        audioError = null,
                    )
                }
            } catch (error: CustomDhikrAudioException) {
                val decision = CreateDhikrAudioDraftPolicy.onReplacementFailed(previousStaged)
                _uiState.update {
                    it.copy(
                        stagedAudio = decision.keepStaged,
                        audioError = error.reason.name,
                    )
                }
            }
        }
    }

    fun removeAudio() {
        val state = _uiState.value
        state.stagedAudio?.let(audioStore::discardStaged)
        val draft = CreateDhikrAudioDraftPolicy.onRemoveClicked(
            hasPersistedOwnedAudio = state.persistedOwnedAudioPresent,
            currentStaged = state.stagedAudio,
        )
        // Draft-only: never delete persisted owned audio until Save.
        check(!draft.shouldDeleteOwnedAudioImmediately)
        _uiState.update {
            it.copy(
                stagedAudio = draft.stagedAudio,
                ownedAudioName = null,
                ownedAudioMissing = false,
                removeOwnedAudioPending = draft.removeOwnedAudioPending,
                audioError = null,
            )
        }
    }

    fun save() {
        val state = _uiState.value
        if (state.arabic.isBlank() || state.isSaving) return

        _uiState.update { it.copy(isSaving = true, audioError = null, saveError = null) }
        viewModelScope.launch {
            try {
                val dhikr = CustomDhikrFactory.create(
                    title = state.title,
                    arabic = state.arabic,
                    transliteration = state.transliteration,
                    translation = state.translation,
                    category = state.category,
                    audioCountPerPlay = state.audioCountPerPlay,
                    id = state.editingDhikrId ?: java.util.UUID.randomUUID(),
                )
                val id = if (state.isEditing) {
                    val updated = dhikrRepository.updateCustomDhikr(dhikr)
                    if (!updated) error("update_failed")
                    dhikr.id
                } else {
                    dhikrRepository.createDhikr(dhikr)
                }
                var attached = false
                var removedOwned = false
                try {
                    when {
                        state.stagedAudio != null -> {
                            dhikrRepository.attachOwnedAudio(id, state.stagedAudio)
                            attached = true
                        }
                        state.removeOwnedAudioPending -> {
                            dhikrRepository.removeOwnedAudio(id)
                            removedOwned = true
                        }
                    }
                    dhikrRepository.setDhikrTags(id, state.selectedTagIds)
                } catch (error: Exception) {
                    // Content may already be persisted; surface partial failure without losing draft.
                    _uiState.update {
                        it.copy(
                            editingDhikrId = id,
                            stagedAudio = if (attached) null else state.stagedAudio,
                            removeOwnedAudioPending = when {
                                attached -> false
                                removedOwned -> false
                                else -> state.removeOwnedAudioPending
                            },
                            persistedOwnedAudioPresent = when {
                                attached -> true
                                removedOwned -> false
                                else -> state.persistedOwnedAudioPresent
                            },
                            saveError = "partial_failure",
                            isSaved = false,
                        )
                    }
                    return@launch
                }
                _uiState.update {
                    it.copy(
                        isSaved = true,
                        stagedAudio = null,
                        removeOwnedAudioPending = false,
                        persistedOwnedAudioPresent = when {
                            attached -> true
                            removedOwned -> false
                            else -> state.persistedOwnedAudioPresent
                        },
                        saveError = null,
                    )
                }
            } catch (error: Exception) {
                _uiState.update {
                    it.copy(saveError = "save_failed", isSaved = false)
                }
            } finally {
                _uiState.update { it.copy(isSaving = false) }
            }
        }
    }

    fun delete() {
        val id = _uiState.value.editingDhikrId ?: return
        viewModelScope.launch {
            dhikrRepository.deleteCustomDhikr(id)
            _uiState.update { it.copy(isDeleted = true) }
        }
    }

    override fun onCleared() {
        _uiState.value.stagedAudio?.let(audioStore::discardStaged)
        super.onCleared()
    }
}
