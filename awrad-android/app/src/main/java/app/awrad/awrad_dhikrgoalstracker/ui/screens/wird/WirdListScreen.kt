package app.awrad.awrad_dhikrgoalstracker.ui.screens.wird

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.ProgressSummary
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.Wird
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdOccasion
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualCard

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WirdListScreen(
    onNavigateBack: () -> Unit,
    onNavigateToWird: (wirdId: String) -> Unit,
    onCreateWird: () -> Unit,
    viewModel: WirdListViewModel = hiltViewModel(),
) {
    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.wird_list_title)) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null)
                    }
                },
                actions = {
                    IconButton(onClick = onCreateWird) {
                        Icon(Icons.Filled.Add, contentDescription = stringResource(R.string.wird_create_title))
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                ),
            )
        },
    ) { padding ->
        WirdLibraryPane(
            onNavigateToWird = onNavigateToWird,
            onCreateWird = onCreateWird,
            viewModel = viewModel,
            modifier = Modifier.padding(padding),
        )
    }
}

/**
 * The wird list body (Your Wirds + Library sections) without any app-bar chrome, so it can be
 * hosted both by the standalone [WirdListScreen] and by the Library screen's Wirds segment.
 * Set [showInlineCreate] when there is no surrounding "create" action (e.g. inside Library).
 */
@Composable
fun WirdLibraryPane(
    onNavigateToWird: (wirdId: String) -> Unit,
    onCreateWird: () -> Unit,
    modifier: Modifier = Modifier,
    contentPadding: PaddingValues = PaddingValues(20.dp),
    showInlineCreate: Boolean = false,
    viewModel: WirdListViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    when {
        state.isLoading -> Box(
            modifier.fillMaxSize(),
            Alignment.Center,
        ) { CircularProgressIndicator() }

        state.custom.isEmpty() && state.library.isEmpty() -> Box(
            modifier
                .fillMaxSize()
                .padding(contentPadding),
            Alignment.Center,
        ) {
            if (showInlineCreate) {
                CreateWirdRow(onCreateWird)
            } else {
                Text(
                    stringResource(R.string.wird_empty),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        else -> LazyColumn(
            modifier = modifier.fillMaxSize(),
            contentPadding = contentPadding,
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            if (showInlineCreate) {
                item { CreateWirdRow(onCreateWird) }
            }
            if (state.custom.isNotEmpty()) {
                item { SectionHeader(stringResource(R.string.wird_your_wirds)) }
                items(state.custom, key = { it.wird.id }) { WirdCard(it, onNavigateToWird) }
            }
            if (state.library.isNotEmpty()) {
                // Only label the library group when a "Your wirds" group sits above it; on its
                // own it reads as a clean, unlabelled catalog.
                if (state.custom.isNotEmpty()) {
                    item { SectionHeader(stringResource(R.string.wird_library)) }
                }
                items(state.library, key = { it.wird.id }) { WirdCard(it, onNavigateToWird) }
            }
        }
    }
}

@Composable
private fun CreateWirdRow(onClick: () -> Unit) {
    RitualCard(onClick = onClick) {
        Row(
            Modifier
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.surface)
                .padding(18.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                Icons.Filled.Add,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
            )
            Spacer(Modifier.width(12.dp))
            Text(
                text = stringResource(R.string.wird_create_title),
                style = MaterialTheme.typography.titleSmall,
            )
        }
    }
}

@Composable
private fun SectionHeader(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(top = 8.dp, bottom = 2.dp),
    )
}

@Composable
private fun WirdCard(item: WirdListItem, onClick: (String) -> Unit) {
    WirdCatalogCard(
        wird = item.wird,
        isActiveToday = item.isActiveToday,
        progress = item.progress,
        onClick = { onClick(item.wird.id) },
    )
}

/**
 * Clean catalog-style card for a wird — title, "author · sections · minutes" meta line, primary
 * tag, and a light today-progress signal. Shared by the Library Wirds pane and the Home screen's
 * featured wirds tab so both read as the same catalog.
 */
@Composable
fun WirdCatalogCard(
    wird: Wird,
    isActiveToday: Boolean,
    progress: ProgressSummary,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val lang = currentLang()
    val meta = wirdMetaLine(wird)
    val tag = wird.tags.firstOrNull()?.let { wirdTagLabel(it) }
        ?: wird.schedule.defaultOccasion
            .takeIf { it != WirdOccasion.Anytime }
            ?.let { occasionLabel(it) }

    RitualCard(
        onClick = onClick,
        modifier = modifier,
        shape = RoundedCornerShape(26.dp),
        containerColor = MaterialTheme.colorScheme.surface,
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 20.dp),
        ) {
            Text(
                text = wird.displayName(lang),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            if (meta.isNotEmpty()) {
                Spacer(Modifier.height(6.dp))
                Text(
                    text = meta,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            if (tag != null) {
                Spacer(Modifier.height(6.dp))
                Text(
                    text = tag,
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
            // Keep a light "today" signal for wirds currently in progress; the clean catalog
            // cards otherwise carry no progress chrome.
            if (isActiveToday && progress.totalItems > 0) {
                when {
                    progress.progress >= 1f -> {
                        Spacer(Modifier.height(14.dp))
                        DoneTodayRow()
                    }

                    progress.progress > 0f -> {
                        Spacer(Modifier.height(14.dp))
                        LinearProgressIndicator(
                            progress = { progress.progress },
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(6.dp)
                                .clip(RoundedCornerShape(50)),
                        )
                    }
                }
            }
        }
    }
}

/** "Author · N sections · N min" — omitting any part the wird doesn't provide. */
@Composable
private fun wirdMetaLine(wird: Wird): String {
    val parts = buildList {
        wird.author.trim().takeIf { it.isNotEmpty() }?.let { add(it) }
        if (wird.parts.isNotEmpty()) {
            add(pluralStringResource(R.plurals.wird_section_count, wird.parts.size, wird.parts.size))
        }
        wird.estimatedMinutes?.takeIf { it > 0 }?.let {
            add(stringResource(R.string.wird_minutes_short, it))
        }
    }
    return parts.joinToString(" · ")
}

@Composable
private fun DoneTodayRow() {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(
            Icons.Filled.Check,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(18.dp),
        )
        Text(
            text = stringResource(R.string.wird_done_today),
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.padding(start = 6.dp),
        )
    }
}
