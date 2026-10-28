package app.awrad.feature.library

import androidx.compose.runtime.State
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.personal.TagError
import app.awrad.core.domain.personal.TagOutcome
import app.awrad.core.domain.personal.TagRepository
import app.awrad.core.domain.personal.UserTag
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject

/** "Manage tags": every tag, by name; create one, rename one in place, or delete one after a confirmation. */
@HiltViewModel
internal class ManageTagsViewModel @Inject constructor(private val tags: TagRepository) : ViewModel() {

    private val mutableState = mutableStateOf(ManageTagsUiState())
    val state: State<ManageTagsUiState> = mutableState

    init {
        viewModelScope.launch {
            tags.tags.collect { list -> mutableState.update { it.copy(isLoading = false, tags = list) } }
        }
    }

    fun onAction(action: ManageTagsAction) {
        when (action) {
            is ManageTagsAction.NewNameChanged ->
                mutableState.update { it.copy(newName = action.name, createError = null) }
            ManageTagsAction.Create -> create()
            is ManageTagsAction.StartRename -> mutableState.update { state ->
                val tag = state.tags.firstOrNull { it.id == action.tagId } ?: return@update state
                state.copy(renaming = Renaming(tag.id, tag.name))
            }
            is ManageTagsAction.RenameChanged ->
                mutableState.update { it.copy(renaming = it.renaming?.copy(name = action.name, error = null)) }
            ManageTagsAction.ConfirmRename -> rename()
            ManageTagsAction.CancelRename -> mutableState.update { it.copy(renaming = null) }
            is ManageTagsAction.AskDelete ->
                mutableState.update { state -> state.copy(deleting = state.tags.firstOrNull { it.id == action.tagId }) }
            ManageTagsAction.CancelDelete -> mutableState.update { it.copy(deleting = null) }
            ManageTagsAction.ConfirmDelete -> delete()
        }
    }

    private fun create() {
        val name = mutableState.value.newName
        viewModelScope.launch {
            when (val outcome = tags.create(name)) {
                is TagOutcome.Saved -> mutableState.update { it.copy(newName = "", createError = null) }
                is TagOutcome.Failed -> mutableState.update { it.copy(createError = outcome.error) }
            }
        }
    }

    private fun rename() {
        val renaming = mutableState.value.renaming ?: return
        viewModelScope.launch {
            when (val outcome = tags.rename(renaming.tagId, renaming.name)) {
                is TagOutcome.Saved -> mutableState.update { it.copy(renaming = null) }
                is TagOutcome.Failed ->
                    mutableState.update { it.copy(renaming = it.renaming?.copy(error = outcome.error)) }
            }
        }
    }

    private fun delete() {
        val tag = mutableState.value.deleting ?: return
        mutableState.update { it.copy(deleting = null) }
        viewModelScope.launch { tags.delete(tag.id) }
    }
}

/** The tag being renamed, its new name as typed, and why the last try failed. */
internal data class Renaming(val tagId: AwradId, val name: String, val error: TagError? = null)

internal data class ManageTagsUiState(
    val isLoading: Boolean = true,
    val tags: List<UserTag> = emptyList(),
    val newName: String = "",
    val createError: TagError? = null,
    val renaming: Renaming? = null,
    /** The tag waiting for the delete confirmation. */
    val deleting: UserTag? = null,
)

internal sealed interface ManageTagsAction {
    data class NewNameChanged(val name: String) : ManageTagsAction

    data object Create : ManageTagsAction

    data class StartRename(val tagId: AwradId) : ManageTagsAction

    data class RenameChanged(val name: String) : ManageTagsAction

    data object ConfirmRename : ManageTagsAction

    data object CancelRename : ManageTagsAction

    data class AskDelete(val tagId: AwradId) : ManageTagsAction

    data object CancelDelete : ManageTagsAction

    data object ConfirmDelete : ManageTagsAction
}
