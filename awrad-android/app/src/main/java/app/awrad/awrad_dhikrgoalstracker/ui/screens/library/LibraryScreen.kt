package app.awrad.awrad_dhikrgoalstracker.ui.screens.library

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.util.lerp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.toStringResId
import app.awrad.awrad_dhikrgoalstracker.service.PreviewPlaybackState
import app.awrad.awrad_dhikrgoalstracker.ui.components.AwradPagerTabs
import app.awrad.awrad_dhikrgoalstracker.ui.components.FeaturedCollectionsSection
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualCard
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualEmptyState
import app.awrad.awrad_dhikrgoalstracker.ui.screens.wird.WirdLibraryPane
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme
import app.awrad.awrad_dhikrgoalstracker.ui.sync.ProgressSyncRefreshViewModel
import kotlinx.coroutines.launch
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.roundToInt

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LibraryScreen(
    onNavigateToCreateGoal: () -> Unit,
    onNavigateToDhikrDetail: (AwradId) -> Unit = {},
    onNavigateToCreateDhikr: () -> Unit = {},
    onNavigateToWird: (String) -> Unit = {},
    onCreateWird: () -> Unit = {},
    viewModel: LibraryViewModel = hiltViewModel(),
    refreshViewModel: ProgressSyncRefreshViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val playerState by viewModel.playerState.collectAsStateWithLifecycle()
    val isRefreshing by refreshViewModel.isRefreshing.collectAsStateWithLifecycle()
    var isSearchVisible by rememberSaveable { mutableStateOf(false) }
    val pagerState = rememberPagerState(initialPage = 0) { 2 }
    val scope = rememberCoroutineScope()
    var tabCentersPx by remember { mutableStateOf(listOf<Float>()) }
    var sheetLeftPx by remember { mutableStateOf(0f) }
    val density = LocalDensity.current
    val statusBarTopPadding = with(density) { WindowInsets.statusBars.getTop(this).toDp() }
    val navBarBottomPadding = with(density) { WindowInsets.navigationBars.getBottom(this).toDp() }
    val headerBackgroundColor = if (isAwradDarkTheme()) {
        MaterialTheme.colorScheme.surfaceContainer
    } else {
        MaterialTheme.colorScheme.surface
    }
    val contentBackgroundColor = if (isAwradDarkTheme()) {
        MaterialTheme.colorScheme.surface
    } else {
        MaterialTheme.colorScheme.surfaceContainer
    }

    val tabs = listOf(
        stringResource(R.string.library_segment_dhikrs),
        stringResource(R.string.library_segment_wirds),
    )

    Scaffold(
        containerColor = Color.Transparent,
        contentWindowInsets = WindowInsets(0),
    ) { scaffoldPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(scaffoldPadding),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(headerBackgroundColor)
                    .padding(top = statusBarTopPadding + 22.dp, bottom = 12.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                LibraryHeader(
                    onSearchClick = {
                        isSearchVisible = !isSearchVisible
                        if (isSearchVisible) {
                            scope.launch { pagerState.animateScrollToPage(0) }
                        } else {
                            viewModel.onSearchQueryChanged("")
                        }
                    },
                )
                AwradPagerTabs(
                    tabs = tabs,
                    pagerState = pagerState,
                    onTabSelected = { index -> scope.launch { pagerState.animateScrollToPage(index) } },
                    onTabCenters = { tabCentersPx = it },
                    unselectedColor = contentBackgroundColor,
                    modifier = Modifier.padding(horizontal = 20.dp),
                )
            }

            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .background(headerBackgroundColor)
                    .onGloballyPositioned { sheetLeftPx = it.positionInRoot().x },
            ) {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
                    color = contentBackgroundColor,
                    shadowElevation = 0.dp,
                ) {
                    PullToRefreshBox(
                        isRefreshing = isRefreshing,
                        onRefresh = refreshViewModel::refresh,
                        modifier = Modifier.fillMaxSize(),
                    ) {
                        HorizontalPager(
                            state = pagerState,
                            modifier = Modifier.fillMaxSize(),
                            beyondViewportPageCount = 1,
                        ) { page ->
                            when (page) {
                                0 -> DhikrLibraryPane(
                                    uiState = uiState,
                                    playerState = playerState,
                                    isSearchVisible = isSearchVisible,
                                    onSearchQueryChange = viewModel::onSearchQueryChanged,
                                    onClearSearch = { viewModel.onSearchQueryChanged("") },
                                    onCollectionClick = { category ->
                                        viewModel.onFeaturedCollectionSelected(category)
                                        isSearchVisible = false
                                    },
                                    onYourDhikrsClick = {
                                        viewModel.onYourDhikrsSelected()
                                        isSearchVisible = false
                                    },
                                    onViewAll = {
                                        viewModel.clearFilters()
                                        isSearchVisible = false
                                    },
                                    onClearFilters = viewModel::clearFilters,
                                    onCreateDhikr = onNavigateToCreateDhikr,
                                    onTogglePlayback = viewModel::togglePlayback,
                                    onNavigateToDhikrDetail = onNavigateToDhikrDetail,
                                    modifier = Modifier.fillMaxSize(),
                                )

                                else -> WirdLibraryPane(
                                    onNavigateToWird = onNavigateToWird,
                                    onCreateWird = onCreateWird,
                                    showInlineCreate = false,
                                    contentPadding = PaddingValues(
                                        start = 20.dp,
                                        end = 20.dp,
                                        top = 18.dp,
                                        bottom = 112.dp,
                                    ),
                                    cardContainerColor = if (isAwradDarkTheme()) {
                                        MaterialTheme.colorScheme.surfaceContainer
                                    } else {
                                        MaterialTheme.colorScheme.surface
                                    },
                                    modifier = Modifier.fillMaxSize(),
                                )
                            }
                        }
                    }
                }

                // Active-tab indicator nub, drawn on the content sheet's top edge under the active tab.
                if (tabCentersPx.isNotEmpty()) {
                    val indicatorPos = (pagerState.currentPage + pagerState.currentPageOffsetFraction)
                        .coerceIn(0f, (tabCentersPx.size - 1).toFloat())
                    val lowerIdx = floor(indicatorPos).toInt().coerceIn(0, tabCentersPx.lastIndex)
                    val upperIdx = ceil(indicatorPos).toInt().coerceIn(0, tabCentersPx.lastIndex)
                    val frac = indicatorPos - lowerIdx
                    val nubWidth = 24.dp
                    val nubCenterX = lerp(tabCentersPx[lowerIdx], tabCentersPx[upperIdx], frac) - sheetLeftPx
                    val nubHalfPx = with(density) { nubWidth.toPx() } / 2f
                    // Lift the nub up off the sheet so it floats in the gap above the content.
                    val nubOffsetYpx = with(density) { 5.dp.toPx() }.roundToInt()
                    Box(
                        modifier = Modifier
                            .align(Alignment.TopStart)
                            .offset { IntOffset((nubCenterX - nubHalfPx).roundToInt(), -nubOffsetYpx) }
                            .width(nubWidth)
                            .height(4.dp)
                            .clip(RoundedCornerShape(percent = 50))
                            .background(MaterialTheme.colorScheme.primary),
                    )
                }

                // Floating create actions: dhikrs on tab 0, wirds on tab 1.
                if (pagerState.currentPage == 0) {
                    FloatingActionButton(
                        onClick = onNavigateToCreateDhikr,
                        shape = CircleShape,
                        containerColor = MaterialTheme.colorScheme.primary,
                        contentColor = MaterialTheme.colorScheme.onPrimary,
                        modifier = Modifier
                            .align(Alignment.BottomEnd)
                            .padding(end = 20.dp, bottom = navBarBottomPadding + 88.dp),
                    ) {
                        Icon(
                            Icons.Filled.Add,
                            contentDescription = stringResource(R.string.create_dhikr_title),
                        )
                    }
                } else if (pagerState.currentPage == 1) {
                    FloatingActionButton(
                        onClick = onCreateWird,
                        shape = CircleShape,
                        containerColor = MaterialTheme.colorScheme.primary,
                        contentColor = MaterialTheme.colorScheme.onPrimary,
                        modifier = Modifier
                            .align(Alignment.BottomEnd)
                            .padding(end = 20.dp, bottom = navBarBottomPadding + 88.dp),
                    ) {
                        Icon(
                            Icons.Filled.Add,
                            contentDescription = stringResource(R.string.wird_create_title),
                        )
                    }
                }
            }
        }
    }

}

@Composable
private fun DhikrLibraryPane(
    uiState: LibraryUiState,
    playerState: PreviewPlaybackState,
    isSearchVisible: Boolean,
    onSearchQueryChange: (String) -> Unit,
    onClearSearch: () -> Unit,
    onCollectionClick: (DhikrCategory) -> Unit,
    onYourDhikrsClick: () -> Unit,
    onViewAll: () -> Unit,
    onClearFilters: () -> Unit,
    onCreateDhikr: () -> Unit,
    onTogglePlayback: (Dhikr) -> Unit,
    onNavigateToDhikrDetail: (AwradId) -> Unit,
    modifier: Modifier = Modifier,
) {
    LazyColumn(
        modifier = modifier,
        contentPadding = PaddingValues(top = 18.dp, bottom = 112.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (isSearchVisible || uiState.searchQuery.isNotBlank()) {
            item {
                Column {
                    LibrarySearchField(
                        query = uiState.searchQuery,
                        onQueryChange = onSearchQueryChange,
                        onClear = onClearSearch,
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                }
            }
        }

        item {
            Column {
                FeaturedCollectionsSection(
                    categoryCounts = uiState.categoryCounts,
                    customCount = uiState.customCount,
                    onCollectionClick = onCollectionClick,
                    onYourDhikrsClick = onYourDhikrsClick,
                    onViewAll = onViewAll,
                )
                Spacer(modifier = Modifier.height(12.dp))
            }
        }

        item {
            Column {
                DhikrListHeader(uiState = uiState)
                Spacer(modifier = Modifier.height(12.dp))
            }
        }

        if (uiState.filteredDhikrs.isEmpty()) {
            item {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    when {
                        uiState.customOnly && uiState.searchQuery.isBlank() -> {
                            RitualEmptyState(
                                title = stringResource(R.string.your_dhikrs_empty_title),
                                body = stringResource(R.string.your_dhikrs_empty_body),
                                icon = Icons.Default.Search,
                                actionLabel = stringResource(R.string.create_dhikr_title),
                                onAction = onCreateDhikr,
                            )
                        }
                        uiState.hasActiveFilters -> {
                            RitualEmptyState(
                                title = stringResource(R.string.library_no_match),
                                body = stringResource(R.string.library_clear_filters_hint),
                                icon = Icons.Default.Search,
                                actionLabel = stringResource(R.string.library_clear_filters),
                                onAction = onClearFilters,
                            )
                        }
                        else -> {
                            RitualEmptyState(
                                title = if (uiState.searchQuery.isNotEmpty()) {
                                    stringResource(R.string.library_no_match)
                                } else {
                                    stringResource(R.string.library_no_dhikrs)
                                },
                                body = stringResource(R.string.library_search_hint),
                                icon = Icons.Default.Search,
                            )
                        }
                    }
                }
            }
        } else {
            items(uiState.filteredDhikrs, key = { it.id }) { dhikr ->
                val hasOwned = uiState.ownedAudioByDhikrId.containsKey(dhikr.id)
                val ownedMissing = dhikr.id in uiState.missingOwnedAudioIds
                LibraryDhikrRow(
                    dhikr = dhikr,
                    isPlaying = playerState.dhikrId == dhikr.id && playerState.isPlaying,
                    canPlay = (dhikr.audioUrl != null || hasOwned) && !ownedMissing,
                    ownedAudioMissing = ownedMissing,
                    onPlayPause = { onTogglePlayback(dhikr) },
                    onClick = { onNavigateToDhikrDetail(dhikr.id) },
                    modifier = Modifier
                        .padding(horizontal = 20.dp),
                )
            }
        }
    }
}

@Composable
private fun LibraryHeader(
    onSearchClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(
                text = stringResource(R.string.library_title),
                style = MaterialTheme.typography.displayMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
            )
        }
        Surface(
            modifier = Modifier
                .padding(start = 18.dp)
                .size(58.dp),
            shape = CircleShape,
            color = if (isAwradDarkTheme()) {
                MaterialTheme.colorScheme.surfaceContainerHigh
            } else {
                MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.58f)
            },
        ) {
            IconButton(onClick = onSearchClick) {
                Icon(
                    imageVector = Icons.Default.Search,
                    contentDescription = stringResource(R.string.library_search_hint),
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(28.dp),
                )
            }
        }
    }
}

@Composable
private fun LibrarySearchField(
    query: String,
    onQueryChange: (String) -> Unit,
    onClear: () -> Unit,
) {
    OutlinedTextField(
        value = query,
        onValueChange = onQueryChange,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp),
        placeholder = { Text(stringResource(R.string.library_search_hint)) },
        leadingIcon = {
            Icon(
                imageVector = Icons.Default.Search,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        },
        trailingIcon = {
            if (query.isNotEmpty()) {
                IconButton(onClick = onClear) {
                    Icon(
                        imageVector = Icons.Default.Clear,
                        contentDescription = stringResource(R.string.cd_clear_search),
                    )
                }
            }
        },
        singleLine = true,
        shape = RoundedCornerShape(22.dp),
        colors = OutlinedTextFieldDefaults.colors(
            unfocusedContainerColor = if (isAwradDarkTheme()) {
                MaterialTheme.colorScheme.surfaceContainerHigh
            } else {
                MaterialTheme.colorScheme.surface
            },
            focusedContainerColor = if (isAwradDarkTheme()) {
                MaterialTheme.colorScheme.surfaceContainerHigh
            } else {
                MaterialTheme.colorScheme.surface
            },
        ),
    )
}

@Composable
private fun DhikrListHeader(
    uiState: LibraryUiState,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = when {
                uiState.customOnly -> stringResource(R.string.collection_your_dhikrs)
                uiState.selectedCategory != null -> stringResource(uiState.selectedCategory.toStringResId())
                else -> stringResource(R.string.all_dhikrs)
            },
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        Text(
            text = stringResource(R.string.collection_count, uiState.filteredDhikrs.size),
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier
                .padding(start = 12.dp)
                .widthIn(min = 72.dp),
        )
    }
}

@Composable
private fun LibraryDhikrRow(
    dhikr: Dhikr,
    isPlaying: Boolean,
    canPlay: Boolean,
    ownedAudioMissing: Boolean,
    onPlayPause: () -> Unit,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    RitualCard(
        onClick = onClick,
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        containerColor = if (isAwradDarkTheme()) {
            MaterialTheme.colorScheme.surfaceContainer
        } else {
            MaterialTheme.colorScheme.surface
        },
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(84.dp)
                .padding(start = 18.dp, end = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = dhikr.title,
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = when {
                        ownedAudioMissing -> stringResource(R.string.audio_missing)
                        else -> dhikr.translation.ifBlank { stringResource(dhikr.category.toStringResId()) }
                    },
                    style = MaterialTheme.typography.bodySmall,
                    color = if (ownedAudioMissing) {
                        MaterialTheme.colorScheme.error
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    },
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = stringResource(dhikr.category.toStringResId()),
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = if (isPlaying) MaterialTheme.colorScheme.secondary else MaterialTheme.colorScheme.primary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            FilledTonalIconButton(
                onClick = onPlayPause,
                enabled = canPlay,
                modifier = Modifier.size(44.dp),
                colors = IconButtonDefaults.filledTonalIconButtonColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                    contentColor = MaterialTheme.colorScheme.primary,
                    disabledContainerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f),
                    disabledContentColor = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.58f),
                ),
            ) {
                Icon(
                    imageVector = if (isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                    contentDescription = if (isPlaying) {
                        stringResource(R.string.cd_pause)
                    } else {
                        stringResource(R.string.cd_play)
                    },
                    modifier = Modifier.size(22.dp),
                )
            }
        }
    }
}
