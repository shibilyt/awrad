package app.awrad.feature.library

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.core.designsystem.component.AwradLargeTitlePage
import app.awrad.core.designsystem.component.AwradSearchField
import app.awrad.core.designsystem.component.AwradSectionTitle
import app.awrad.core.designsystem.component.AwradTextButton
import app.awrad.core.designsystem.component.awradBottomBarPadding
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.core.domain.dhikr.ContentLanguage
import app.awrad.core.domain.dhikr.Dhikr

/** Stateful Library tab: the ViewModel, and the app's language sent to it. */
@Composable
internal fun LibraryRoute(
    onNavigate: (LibraryDestination) -> Unit,
    modifier: Modifier = Modifier,
    viewModel: LibraryViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val language = currentContentLanguage()
    LaunchedEffect(language) { viewModel.onAction(LibraryAction.LanguageChanged(language)) }
    LibraryScreen(state = state, onAction = viewModel::onAction, onNavigate = onNavigate, modifier = modifier)
}

/**
 * The Library: the large "Library" header, the search field, then the collection tiles and "All dhikrs"; while
 * searching, the results only, or an empty state. The list clears the floating bottom bar.
 */
@Composable
internal fun LibraryScreen(
    state: LibraryUiState,
    onAction: (LibraryAction) -> Unit,
    onNavigate: (LibraryDestination) -> Unit,
    modifier: Modifier = Modifier,
) {
    val spacing = AwradTheme.spacing
    AwradLargeTitlePage(
        title = stringResource(R.string.library_title),
        modifier = modifier
            .fillMaxSize()
            .statusBarsPadding(),
    ) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = awradBottomBarPadding(),
            verticalArrangement = Arrangement.spacedBy(spacing.rowGap),
        ) {
            item(key = "search") {
                AwradSearchField(
                    value = state.query,
                    onValueChange = { onAction(LibraryAction.QueryChanged(it)) },
                    placeholder = stringResource(R.string.library_search_placeholder),
                    modifier = Modifier.padding(horizontal = spacing.pageMargin),
                )
            }
            val results = state.results
            if (results != null) {
                searchResults(results, state.query, state.language, onNavigate)
            } else {
                wholeLibrary(state, onNavigate)
            }
        }
    }
}

private fun LazyListScope.wholeLibrary(state: LibraryUiState, onNavigate: (LibraryDestination) -> Unit) {
    item(key = "collectionsTitle") {
        AwradSectionTitle(
            text = stringResource(R.string.library_collections),
            modifier = Modifier.padding(horizontal = AwradTheme.spacing.pageMargin, vertical = AwradTheme.spacing.xs),
        )
    }
    item(key = "collections") {
        CollectionTilesRow(
            collections = state.collections,
            language = state.language,
            onOpen = { onNavigate(LibraryDestination.Collection(it.key)) },
        )
    }
    item(key = "allTitle") {
        AwradSectionTitle(
            text = stringResource(R.string.library_all_dhikrs),
            modifier = Modifier.padding(horizontal = AwradTheme.spacing.pageMargin, vertical = AwradTheme.spacing.xs),
        )
    }
    dhikrRows(state.dhikrs, state.language, onNavigate)
}

private fun LazyListScope.searchResults(
    results: List<Dhikr>,
    query: String,
    language: ContentLanguage,
    onNavigate: (LibraryDestination) -> Unit,
) {
    if (results.isEmpty()) {
        item(key = "empty") { NoResults(query = query.trim()) }
    } else {
        dhikrRows(results, language, onNavigate)
    }
}

private fun LazyListScope.dhikrRows(
    dhikrs: List<Dhikr>,
    language: ContentLanguage,
    onNavigate: (LibraryDestination) -> Unit,
) {
    items(dhikrs, key = { it.key }) { dhikr ->
        DhikrRow(
            dhikr = dhikr,
            language = language,
            onClick = { onNavigate(LibraryDestination.Dhikr(dhikr.key)) },
            modifier = Modifier.padding(horizontal = AwradTheme.spacing.pageMargin),
        )
    }
}

/** Nothing matched: what was searched for, and what to try. Announced when it appears. */
@Composable
private fun NoResults(query: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = AwradTheme.spacing.pageMargin, vertical = AwradTheme.spacing.xl3)
            .semantics(mergeDescendants = true) { liveRegion = LiveRegionMode.Polite },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.xs),
    ) {
        Text(
            text = stringResource(R.string.library_no_results, query),
            style = AwradTheme.type.cardTitle,
            color = AwradTheme.colors.onSurface,
            textAlign = TextAlign.Center,
        )
        Text(
            text = stringResource(R.string.library_no_results_hint),
            style = AwradTheme.type.body,
            color = AwradTheme.colors.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )
    }
}

/** Stateful featured row on Home; it shares the tab shell's [LibraryViewModel] with the Library tab. */
@Composable
internal fun FeaturedCollectionsRoute(
    onNavigate: (LibraryDestination) -> Unit,
    onViewAll: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: LibraryViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    FeaturedCollectionsSection(
        state = state,
        language = currentContentLanguage(),
        onNavigate = onNavigate,
        onViewAll = onViewAll,
        modifier = modifier,
    )
}

/** "Featured dhikr collections" (`sectionTitle`) with "View all" at the end, then the tiles. */
@Composable
internal fun FeaturedCollectionsSection(
    state: LibraryUiState,
    language: ContentLanguage,
    onNavigate: (LibraryDestination) -> Unit,
    onViewAll: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val spacing = AwradTheme.spacing
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(spacing.xs)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                // "View all" pads its label by `md`; its text lines up with the page margin.
                .padding(start = spacing.pageMargin, end = spacing.pageMargin - spacing.md),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            AwradSectionTitle(
                text = stringResource(R.string.library_featured_collections),
                modifier = Modifier.weight(1f),
            )
            AwradTextButton(text = stringResource(R.string.library_view_all), onClick = onViewAll)
        }
        CollectionTilesRow(
            collections = state.collections,
            language = language,
            onOpen = { onNavigate(LibraryDestination.Collection(it.key)) },
        )
    }
}
