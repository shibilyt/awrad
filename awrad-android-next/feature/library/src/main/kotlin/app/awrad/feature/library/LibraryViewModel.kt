package app.awrad.feature.library

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.dhikr.Collection
import app.awrad.core.domain.dhikr.ContentLanguage
import app.awrad.core.domain.dhikr.Dhikr
import app.awrad.core.domain.dhikr.DhikrCatalogSource
import app.awrad.core.domain.dhikr.DhikrSearch
import app.awrad.core.domain.personal.CustomDhikr
import app.awrad.core.domain.personal.CustomDhikrRepository
import app.awrad.core.domain.personal.TagFilter
import app.awrad.core.domain.personal.TagRepository
import app.awrad.core.domain.personal.UserTag
import app.awrad.core.domain.personal.asDhikr
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * The Library tab and Home's featured collections (one instance per tab shell): the catalog's collections and
 * dhikrs, the user's own dhikrs ("Your dhikrs"), the search over all of them in the app's language, and the tag
 * filter (a dhikr shows when it has every selected tag).
 */
@HiltViewModel
internal class LibraryViewModel @Inject constructor(
    private val catalogSource: DhikrCatalogSource,
    private val customDhikrs: CustomDhikrRepository,
    private val tags: TagRepository,
) : ViewModel() {

    private val mutableState = MutableStateFlow(LibraryUiState())
    val state: StateFlow<LibraryUiState> = mutableState.asStateFlow()

    private var search: DhikrSearch? = null

    init {
        viewModelScope.launch {
            val loaded = catalogSource.catalog()
            combine(customDhikrs.dhikrs, tags.tags, tags.tagsByDhikr, ::Personal).collect { personal ->
                val yours = personal.dhikrs.map { it.asDhikr() }
                search = DhikrSearch(yours + loaded.dhikrs)
                mutableState.update { state ->
                    state.copy(
                        isLoading = false,
                        collections = loaded.collections,
                        dhikrs = loaded.dhikrs,
                        yourDhikrs = yours,
                        tags = personal.tags,
                        tagsByDhikr = personal.tagsByDhikr,
                        selectedTags = state.selectedTags intersect personal.tags.map { it.id }.toSet(),
                    ).searched()
                }
            }
        }
    }

    fun onAction(action: LibraryAction) {
        when (action) {
            is LibraryAction.QueryChanged -> mutableState.update { it.copy(query = action.query).searched() }
            is LibraryAction.LanguageChanged -> mutableState.update {
                if (it.language == action.language) it else it.copy(language = action.language).searched()
            }
            is LibraryAction.TagToggled -> mutableState.update {
                val tag = action.tagId
                it.copy(selectedTags = if (tag in it.selectedTags) it.selectedTags - tag else it.selectedTags + tag)
                    .searched()
            }
            LibraryAction.ClearTags -> mutableState.update { it.copy(selectedTags = emptySet()).searched() }
        }
    }

    /** This state with [LibraryUiState.results] for its query and tags: null when neither filters. */
    private fun LibraryUiState.searched(): LibraryUiState {
        val search = search ?: return this
        val matches = when {
            query.isNotBlank() -> search.search(query, language)
            selectedTags.isNotEmpty() -> yourDhikrs + dhikrs
            else -> null
        }
        return copy(results = matches?.let { TagFilter.filter(it, selectedTags, tagsByDhikr) { dhikr -> dhikr.id } })
    }

    private class Personal(
        val dhikrs: List<CustomDhikr>,
        val tags: List<UserTag>,
        val tagsByDhikr: Map<AwradId, List<AwradId>>,
    )
}

/**
 * [collections] and [dhikrs] in catalog order, and [yourDhikrs] newest first. While the [query] isn't blank or
 * tags are [selectedTags], [results] are the matches (best first, possibly none); otherwise [results] is null and
 * the whole library shows.
 */
internal data class LibraryUiState(
    val isLoading: Boolean = true,
    val collections: List<Collection> = emptyList(),
    val dhikrs: List<Dhikr> = emptyList(),
    val yourDhikrs: List<Dhikr> = emptyList(),
    val tags: List<UserTag> = emptyList(),
    val tagsByDhikr: Map<AwradId, List<AwradId>> = emptyMap(),
    val selectedTags: Set<AwradId> = emptySet(),
    val language: ContentLanguage = ContentLanguage.EN,
    val query: String = "",
    val results: List<Dhikr>? = null,
)

internal sealed interface LibraryAction {
    data class QueryChanged(val query: String) : LibraryAction

    /** The app's language, which picks the translation search reads; sent on start and when it changes. */
    data class LanguageChanged(val language: ContentLanguage) : LibraryAction

    /** Adds the tag to the filter, or takes it out. */
    data class TagToggled(val tagId: AwradId) : LibraryAction

    data object ClearTags : LibraryAction
}
