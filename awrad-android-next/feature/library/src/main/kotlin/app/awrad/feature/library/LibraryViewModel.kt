package app.awrad.feature.library

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.core.domain.dhikr.Collection
import app.awrad.core.domain.dhikr.ContentLanguage
import app.awrad.core.domain.dhikr.Dhikr
import app.awrad.core.domain.dhikr.DhikrCatalogSource
import app.awrad.core.domain.dhikr.DhikrSearch
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * The Library tab and Home's featured collections (one instance per tab shell): the catalog's collections and
 * dhikrs, and the search over them in the app's language.
 */
@HiltViewModel
internal class LibraryViewModel @Inject constructor(
    private val catalogSource: DhikrCatalogSource,
) : ViewModel() {

    private val mutableState = MutableStateFlow(LibraryUiState())
    val state: StateFlow<LibraryUiState> = mutableState.asStateFlow()

    private var search: DhikrSearch? = null

    init {
        viewModelScope.launch {
            val catalog = catalogSource.catalog()
            search = DhikrSearch(catalog.dhikrs)
            mutableState.update {
                it.copy(isLoading = false, collections = catalog.collections, dhikrs = catalog.dhikrs).searched()
            }
        }
    }

    fun onAction(action: LibraryAction) {
        when (action) {
            is LibraryAction.QueryChanged -> mutableState.update { it.copy(query = action.query).searched() }
            is LibraryAction.LanguageChanged -> mutableState.update {
                if (it.language == action.language) it else it.copy(language = action.language).searched()
            }
        }
    }

    /** This state with [LibraryUiState.results] for its query: null when the query is blank. */
    private fun LibraryUiState.searched(): LibraryUiState {
        val search = search ?: return this
        return copy(results = query.takeIf { it.isNotBlank() }?.let { search.search(it, language) })
    }
}

/**
 * [collections] and [dhikrs] in catalog order. While the [query] isn't blank, [results] are the matches for it
 * in [language], best first (possibly none); otherwise [results] is null and the whole library shows.
 */
internal data class LibraryUiState(
    val isLoading: Boolean = true,
    val collections: List<Collection> = emptyList(),
    val dhikrs: List<Dhikr> = emptyList(),
    val language: ContentLanguage = ContentLanguage.EN,
    val query: String = "",
    val results: List<Dhikr>? = null,
)

internal sealed interface LibraryAction {
    data class QueryChanged(val query: String) : LibraryAction

    /** The app's language, which picks the translation search reads; sent on start and when it changes. */
    data class LanguageChanged(val language: ContentLanguage) : LibraryAction
}
