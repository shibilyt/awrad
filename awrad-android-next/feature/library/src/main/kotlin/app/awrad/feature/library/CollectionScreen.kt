package app.awrad.feature.library

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import app.awrad.core.designsystem.component.AwradTopBar
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.core.domain.dhikr.Collection
import app.awrad.core.domain.dhikr.DhikrCatalogSource
import dagger.assisted.Assisted
import dagger.assisted.AssistedFactory
import dagger.assisted.AssistedInject
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/** One collection, by its catalog [key]. */
@HiltViewModel(assistedFactory = CollectionViewModel.Factory::class)
internal class CollectionViewModel @AssistedInject constructor(
    @Assisted private val key: String,
    catalogSource: DhikrCatalogSource,
) : ViewModel() {

    private val mutableState = MutableStateFlow<CollectionUiState>(CollectionUiState.Loading)
    val state: StateFlow<CollectionUiState> = mutableState.asStateFlow()

    init {
        viewModelScope.launch {
            val collection = catalogSource.catalog().collection(key)
            mutableState.value = collection?.let(CollectionUiState::Ready) ?: CollectionUiState.Missing
        }
    }

    @AssistedFactory
    interface Factory {
        fun create(key: String): CollectionViewModel
    }
}

internal sealed interface CollectionUiState {
    data object Loading : CollectionUiState

    /** No collection has the key (a stale link); the page says so. */
    data object Missing : CollectionUiState

    data class Ready(val collection: Collection) : CollectionUiState
}

@Composable
internal fun CollectionRoute(
    collectionKey: String,
    onOpenDhikr: (String) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: CollectionViewModel = hiltViewModel<CollectionViewModel, CollectionViewModel.Factory>(
        key = collectionKey,
        creationCallback = { it.create(collectionKey) },
    ),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    CollectionScreen(state = state, onOpenDhikr = onOpenDhikr, onBack = onBack, modifier = modifier)
}

/** A top bar with Back and the collection's title, then its dhikrs in order. */
@Composable
internal fun CollectionScreen(
    state: CollectionUiState,
    onOpenDhikr: (String) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val language = currentContentLanguage()
    val spacing = AwradTheme.spacing
    val navigationBar = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(AwradTheme.colors.background)
            .statusBarsPadding(),
    ) {
        val title = (state as? CollectionUiState.Ready)?.collection?.title?.localized(language)
        AwradTopBar(title = title, onBack = onBack)
        when (state) {
            CollectionUiState.Loading -> Unit
            CollectionUiState.Missing -> MissingContent()
            is CollectionUiState.Ready -> LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(
                    start = spacing.pageMargin,
                    end = spacing.pageMargin,
                    top = spacing.sm,
                    bottom = spacing.sectionGap + navigationBar,
                ),
                verticalArrangement = Arrangement.spacedBy(spacing.rowGap),
            ) {
                items(state.collection.dhikrs, key = { it.key }) { dhikr ->
                    DhikrRow(dhikr = dhikr, language = language, onClick = { onOpenDhikr(dhikr.key) })
                }
            }
        }
    }
}

/** A stale link: the dhikr or collection isn't in the catalog. */
@Composable
internal fun MissingContent(modifier: Modifier = Modifier) {
    Box(modifier = modifier.fillMaxSize().padding(AwradTheme.spacing.pageMargin), contentAlignment = Alignment.Center) {
        Text(
            text = stringResource(R.string.library_missing),
            style = AwradTheme.type.body,
            color = AwradTheme.colors.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )
    }
}
