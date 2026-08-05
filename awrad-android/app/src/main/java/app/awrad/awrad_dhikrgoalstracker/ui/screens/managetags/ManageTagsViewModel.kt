package app.awrad.awrad_dhikrgoalstracker.ui.screens.managetags

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.UserTag
import app.awrad.awrad_dhikrgoalstracker.data.repository.CustomDhikrMutationPolicy
import app.awrad.awrad_dhikrgoalstracker.data.repository.DhikrRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import java.util.UUID
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class ManageTagsUiState(
    val dhikrId: AwradId? = null,
    val dhikrTitle: String = "",
    val dhikrIsCustom: Boolean = false,
    val allTags: List<UserTag> = emptyList(),
    val assignedTagIds: Set<AwradId> = emptySet(),
    val newTagName: String = "",
    val renamingTagId: AwradId? = null,
    val renameText: String = "",
    val errorMessage: String? = null,
    val isLoading: Boolean = true,
)

@HiltViewModel
class ManageTagsViewModel @Inject constructor(
    private val dhikrRepository: DhikrRepository,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val dhikrId: AwradId = UUID.fromString(checkNotNull(savedStateHandle["dhikrId"] as String?))

    private val _draft = MutableStateFlow(ManageTagsUiState(dhikrId = dhikrId))

    val uiState: StateFlow<ManageTagsUiState> = combine(
        _draft,
        dhikrRepository.observeUserTags(),
        dhikrRepository.observeTagIdsForDhikr(dhikrId),
    ) { draft, tags, assigned ->
        draft.copy(
            allTags = tags,
            assignedTagIds = assigned,
            isLoading = false,
        )
    }.stateIn(viewModelScope, SharingStarted.Eagerly, ManageTagsUiState(dhikrId = dhikrId))

    init {
        viewModelScope.launch {
            val dhikr = dhikrRepository.getDhikrById(dhikrId)
            _draft.update {
                it.copy(
                    dhikrTitle = dhikr?.title.orEmpty(),
                    dhikrIsCustom = dhikr?.isCustom == true,
                    isLoading = false,
                )
            }
        }
    }

    fun onNewTagNameChanged(value: String) {
        _draft.update { it.copy(newTagName = value, errorMessage = null) }
    }

    fun createTag() {
        val raw = _draft.value.newTagName
        viewModelScope.launch {
            val assigned = uiState.value.assignedTagIds
            if (!CustomDhikrMutationPolicy.canAssignTag(assigned.size)) {
                _draft.update { it.copy(errorMessage = "too_many_tags") }
                return@launch
            }
            val created = dhikrRepository.createUserTag(raw)
            if (created == null) {
                _draft.update { it.copy(errorMessage = "invalid_tag") }
                return@launch
            }
            dhikrRepository.setDhikrTags(dhikrId, assigned + created.id)
            _draft.update { it.copy(newTagName = "", errorMessage = null) }
        }
    }

    fun toggleAssignment(tagId: AwradId) {
        viewModelScope.launch {
            val current = uiState.value.assignedTagIds
            val next = if (tagId in current) {
                current - tagId
            } else {
                if (!CustomDhikrMutationPolicy.canAssignTag(current.size)) {
                    _draft.update { it.copy(errorMessage = "too_many_tags") }
                    return@launch
                }
                current + tagId
            }
            dhikrRepository.setDhikrTags(dhikrId, next)
            _draft.update { it.copy(errorMessage = null) }
        }
    }

    fun beginRename(tagId: AwradId) {
        val tag = uiState.value.allTags.firstOrNull { it.id == tagId } ?: return
        _draft.update { it.copy(renamingTagId = tagId, renameText = tag.name, errorMessage = null) }
    }

    fun onRenameTextChanged(value: String) {
        _draft.update { it.copy(renameText = value) }
    }

    fun commitRename() {
        val tagId = _draft.value.renamingTagId ?: return
        val text = _draft.value.renameText
        viewModelScope.launch {
            val renamed = dhikrRepository.renameUserTag(tagId, text)
            if (renamed == null) {
                _draft.update { it.copy(errorMessage = "invalid_tag") }
                return@launch
            }
            _draft.update { it.copy(renamingTagId = null, renameText = "", errorMessage = null) }
        }
    }

    fun cancelRename() {
        _draft.update { it.copy(renamingTagId = null, renameText = "") }
    }

    fun deleteTag(tagId: AwradId) {
        viewModelScope.launch {
            dhikrRepository.deleteUserTag(tagId)
            _draft.update {
                it.copy(
                    renamingTagId = if (it.renamingTagId == tagId) null else it.renamingTagId,
                    errorMessage = null,
                )
            }
        }
    }
}
