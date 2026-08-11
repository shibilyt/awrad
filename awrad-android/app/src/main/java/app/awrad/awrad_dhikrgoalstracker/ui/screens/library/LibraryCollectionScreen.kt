package app.awrad.awrad_dhikrgoalstracker.ui.screens.library

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualEmptyState
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LibraryCollectionScreen(
    collection: LibraryFeaturedCollection,
    onNavigateBack: () -> Unit,
    onNavigateToDhikrDetail: (AwradId) -> Unit,
    onNavigateToCreateDhikr: () -> Unit = {},
    viewModel: LibraryViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val playerState by viewModel.playerState.collectAsStateWithLifecycle()
    val dhikrs = remember(collection, uiState.allDhikrs) {
        collection.dhikrsFrom(uiState.allDhikrs)
    }
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

    Scaffold(
        containerColor = contentBackgroundColor,
        contentWindowInsets = WindowInsets(0),
        topBar = {
            TopAppBar(
                windowInsets = WindowInsets.statusBars,
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = headerBackgroundColor,
                    scrolledContainerColor = headerBackgroundColor,
                ),
                title = {
                    Text(
                        text = stringResource(collection.titleRes),
                        fontWeight = FontWeight.Bold,
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.action_back),
                        )
                    }
                },
            )
        },
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = PaddingValues(top = 20.dp, bottom = 112.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            item {
                Text(
                    text = stringResource(R.string.collection_count, dhikrs.size),
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.padding(horizontal = 20.dp, vertical = 4.dp),
                )
            }

            if (dhikrs.isEmpty()) {
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 20.dp, vertical = 24.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        if (collection == LibraryFeaturedCollection.YOUR_DHIKRS) {
                            RitualEmptyState(
                                title = stringResource(R.string.your_dhikrs_empty_title),
                                body = stringResource(R.string.your_dhikrs_empty_body),
                                icon = Icons.Default.Add,
                                actionLabel = stringResource(R.string.create_dhikr_title),
                                onAction = onNavigateToCreateDhikr,
                            )
                        } else {
                            RitualEmptyState(
                                title = stringResource(R.string.category_no_dhikrs),
                                body = stringResource(R.string.library_no_dhikrs),
                                icon = Icons.Default.Search,
                            )
                        }
                    }
                }
            } else {
                items(dhikrs, key = { it.id }) { dhikr ->
                    val hasOwned = uiState.ownedAudioByDhikrId.containsKey(dhikr.id)
                    val ownedMissing = dhikr.id in uiState.missingOwnedAudioIds
                    LibraryDhikrRow(
                        dhikr = dhikr,
                        isPlaying = playerState.dhikrId == dhikr.id && playerState.isPlaying,
                        canPlay = (dhikr.audioUrl != null || hasOwned) && !ownedMissing,
                        ownedAudioMissing = ownedMissing,
                        onPlayPause = { viewModel.togglePlayback(dhikr) },
                        onClick = { onNavigateToDhikrDetail(dhikr.id) },
                        modifier = Modifier.padding(horizontal = 20.dp),
                    )
                }
            }
        }
    }
}
