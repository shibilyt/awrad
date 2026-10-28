package app.awrad.feature.library

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.personal.TagError
import app.awrad.core.domain.personal.TagOutcome
import app.awrad.core.domain.personal.TagRepository
import app.awrad.core.domain.personal.UserTag
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** The "Manage tags" sheet of a dhikr while it's open: the new tag's name and why it couldn't be made. */
internal data class TagSheetState(val newName: String = "", val error: TagError? = null)

internal sealed interface TagSheetAction {
    data object Open : TagSheetAction

    data object Close : TagSheetAction

    /** Adds the tag to the dhikr, or takes it off. */
    data class Toggle(val tagId: AwradId) : TagSheetAction

    data class NameChanged(val name: String) : TagSheetAction

    /** Creates a tag with the typed name and adds it to the dhikr. */
    data object Create : TagSheetAction
}

/**
 * The dhikr page's tag sheet: toggles the dhikr's tags (in the order they were added) and creates new ones. It
 * writes through [tags], whose flows bring the change back into the page's state.
 */
internal class DhikrTagSheet(
    private val tags: TagRepository,
    private val scope: CoroutineScope,
    private val state: MutableStateFlow<DhikrDetailUiState>,
) {
    fun onAction(action: TagSheetAction, dhikrId: AwradId?) {
        when (action) {
            TagSheetAction.Open -> state.update { it.copy(sheet = TagSheetState()) }
            TagSheetAction.Close -> state.update { it.copy(sheet = null) }
            is TagSheetAction.NameChanged ->
                state.update { it.copy(sheet = it.sheet?.copy(newName = action.name, error = null)) }
            is TagSheetAction.Toggle -> dhikrId?.let { toggle(it, action.tagId) }
            TagSheetAction.Create -> dhikrId?.let(::create)
        }
    }

    private fun toggle(dhikrId: AwradId, tagId: AwradId) {
        val current = state.value.tags.map(UserTag::id)
        val next = if (tagId in current) current - tagId else current + tagId
        scope.launch { setTags(dhikrId, next) }
    }

    private fun create(dhikrId: AwradId) {
        val name = state.value.sheet?.newName ?: return
        scope.launch {
            when (val outcome = tags.create(name)) {
                is TagOutcome.Saved -> {
                    state.update { it.copy(sheet = it.sheet?.copy(newName = "", error = null)) }
                    setTags(dhikrId, state.value.tags.map(UserTag::id) + outcome.tag.id)
                }
                is TagOutcome.Failed -> state.update { it.copy(sheet = it.sheet?.copy(error = outcome.error)) }
            }
        }
    }

    private suspend fun setTags(dhikrId: AwradId, tagIds: List<AwradId>) {
        val error = tags.setTags(dhikrId, tagIds) ?: return
        state.update { it.copy(sheet = it.sheet?.copy(error = error)) }
    }
}
