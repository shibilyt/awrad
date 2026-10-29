package app.awrad.feature.practice

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.hilt.navigation.compose.hiltViewModel
import app.awrad.core.designsystem.component.AwradCard
import app.awrad.core.designsystem.component.AwradCardSize
import app.awrad.core.designsystem.component.AwradSearchField
import app.awrad.core.designsystem.component.AwradSectionTitle
import app.awrad.core.designsystem.component.AwradTopBar
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.core.domain.places.City
import app.awrad.core.domain.places.FoundPlace

@Composable
internal fun LocationSearchRoute(
    sessionKey: String,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: LocationSearchViewModel = hiltViewModel(key = sessionKey),
) {
    val state by viewModel.state
    val close by rememberUpdatedState(onClose)
    LaunchedEffect(state.chosen) { if (state.chosen) close() }
    LocationSearchScreen(state = state, onAction = viewModel::onAction, onBack = onClose, modifier = modifier)
}

/**
 * "Choose a place": a top bar with Back, the search field, then "Cities" (the bundled list, offline) and, when the
 * phone is online and the platform's search finds any, "More places" under their own heading. The list's GeoNames
 * attribution closes the page, as its licence asks.
 */
@Composable
internal fun LocationSearchScreen(
    state: LocationSearchUiState,
    onAction: (LocationSearchAction) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val spacing = AwradTheme.spacing
    val navigationBar = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(AwradTheme.colors.background)
            .statusBarsPadding(),
    ) {
        AwradTopBar(title = stringResource(R.string.practice_search_title), onBack = onBack)
        AwradSearchField(
            value = state.query,
            onValueChange = { onAction(LocationSearchAction.QueryChanged(it)) },
            placeholder = stringResource(R.string.practice_search_placeholder),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = spacing.pageMargin),
        )
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(
                start = spacing.pageMargin,
                end = spacing.pageMargin,
                top = spacing.sectionGap,
                bottom = spacing.sectionGap + navigationBar,
            ),
            verticalArrangement = Arrangement.spacedBy(spacing.rowGap),
        ) {
            results(state = state, onAction = onAction)
            if (state.attribution.isNotEmpty()) {
                item(key = "attribution") {
                    Text(
                        text = state.attribution,
                        modifier = Modifier.padding(top = spacing.sm),
                        style = AwradTheme.type.caption,
                        color = AwradTheme.colors.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

private fun androidx.compose.foundation.lazy.LazyListScope.results(
    state: LocationSearchUiState,
    onAction: (LocationSearchAction) -> Unit,
) {
    val searched = state.query.isNotBlank() && !state.isLoading
    if (searched && state.cities.isEmpty() && state.places.isEmpty()) {
        item(key = "empty") {
            Text(
                text = stringResource(R.string.practice_search_empty, state.query.trim()),
                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                style = AwradTheme.type.body,
                color = AwradTheme.colors.onSurfaceVariant,
            )
        }
    }
    if (state.cities.isNotEmpty()) {
        item(key = "cities") { AwradSectionTitle(text = stringResource(R.string.practice_search_cities)) }
        items(state.cities, key = { "city-${it.id}" }) { city ->
            CityRow(city = city, onClick = { onAction(LocationSearchAction.ChooseCity(city)) })
        }
    }
    if (state.places.isNotEmpty()) {
        item(key = "places") { AwradSectionTitle(text = stringResource(R.string.practice_search_more)) }
        items(state.places, key = { "place-${it.name}-${it.latitude}-${it.longitude}" }) { place ->
            PlaceRow(place = place, onClick = { onAction(LocationSearchAction.ChoosePlace(place)) })
        }
    }
}

/** A bundled city: its name, then its region and country (the country named in the app's language). */
@Composable
private fun CityRow(city: City, onClick: () -> Unit, modifier: Modifier = Modifier) {
    val country = countryName(city.country)
    ResultTile(
        title = city.name,
        detail = listOfNotNull(city.region, country).joinToString(stringResource(R.string.practice_list_separator)),
        onClick = onClick,
        modifier = modifier,
    )
}

@Composable
private fun PlaceRow(place: FoundPlace, onClick: () -> Unit, modifier: Modifier = Modifier) {
    ResultTile(title = place.name, detail = null, onClick = onClick, modifier = modifier)
}

@Composable
private fun ResultTile(title: String, detail: String?, onClick: () -> Unit, modifier: Modifier = Modifier) {
    AwradCard(onClick = onClick, modifier = modifier, size = AwradCardSize.Tile, spacing = AwradTheme.spacing.xxs) {
        Text(text = title, style = AwradTheme.type.rowTitle, color = AwradTheme.colors.onSurface)
        detail?.let { Text(text = it, style = AwradTheme.type.bodySmall, color = AwradTheme.colors.onSurfaceVariant) }
    }
}
