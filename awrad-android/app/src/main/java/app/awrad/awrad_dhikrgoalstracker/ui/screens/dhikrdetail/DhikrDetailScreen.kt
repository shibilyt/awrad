package app.awrad.awrad_dhikrgoalstracker.ui.screens.dhikrdetail

import app.awrad.awrad_dhikrgoalstracker.ui.theme.NotoNaskhArabicFontFamily
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.Tab
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.LayoutDirection
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.SuggestedGoal
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.FrequencyType
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualCard
import app.awrad.awrad_dhikrgoalstracker.ui.components.StreakSection
import app.awrad.awrad_dhikrgoalstracker.ui.components.quran.QuranDhikrTextPreview
import java.text.NumberFormat

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DhikrDetailScreen(
    onNavigateBack: () -> Unit,
    onNavigateToCreateGoal: () -> Unit = {},
    onNavigateToQuranReader: (AwradId) -> Unit = {},
    onNavigateToEditDhikr: (AwradId) -> Unit = {},
    onNavigateToManageTags: (AwradId) -> Unit = {},
    viewModel: DhikrDetailViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val playerState by viewModel.playerState.collectAsStateWithLifecycle()
    val isDownloading by viewModel.isDownloading.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    var showInsights by rememberSaveable { mutableStateOf(true) }
    var statsRange by rememberSaveable { mutableStateOf(DhikrStatsRange.THIRTY_DAYS) }
    var showActions by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        viewModel.goalCreatedMessage.collect { message ->
            snackbarHostState.showSnackbar(message)
        }
    }

    LaunchedEffect(uiState.isDeleted) {
        if (uiState.isDeleted) onNavigateBack()
    }

    // Confirmation dialog
    val pendingConfirmation = uiState.pendingConfirmation
    if (pendingConfirmation != null) {
        AddGoalConfirmationDialog(
            suggestion = pendingConfirmation,
            dhikrName = uiState.dhikr?.transliteration ?: "",
            onConfirm = viewModel::confirmAddGoal,
            onDismiss = viewModel::dismissConfirmation,
        )
    }

    if (uiState.showDeleteConfirm) {
        AlertDialog(
            onDismissRequest = viewModel::dismissDelete,
            title = { Text(stringResource(R.string.delete_dhikr_confirm_title)) },
            text = { Text(stringResource(R.string.delete_dhikr_confirm_body)) },
            confirmButton = {
                Button(onClick = viewModel::confirmDelete) {
                    Text(stringResource(R.string.delete_dhikr))
                }
            },
            dismissButton = {
                OutlinedButton(onClick = viewModel::dismissDelete) {
                    Text(stringResource(R.string.action_cancel))
                }
            },
        )
    }

    if (showActions) {
        uiState.dhikr?.let { dhikr ->
            DhikrActionsBottomSheet(
                isCustom = dhikr.isCustom,
                onDismiss = { showActions = false },
                onManageTags = {
                    showActions = false
                    onNavigateToManageTags(dhikr.id)
                },
                onEdit = {
                    showActions = false
                    onNavigateToEditDhikr(dhikr.id)
                },
                onDelete = {
                    showActions = false
                    viewModel.requestDelete()
                },
            )
        }
    }

    Scaffold(
        containerColor = androidx.compose.ui.graphics.Color.Transparent,
        contentWindowInsets = WindowInsets(0),
        topBar = {
            TopAppBar(
                windowInsets = WindowInsets.statusBars,
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = androidx.compose.ui.graphics.Color.Transparent,
                    scrolledContainerColor = androidx.compose.ui.graphics.Color.Transparent,
                    navigationIconContentColor = MaterialTheme.colorScheme.onSurface,
                    titleContentColor = MaterialTheme.colorScheme.onSurface,
                    actionIconContentColor = MaterialTheme.colorScheme.onSurface,
                ),
                title = {
                    Text(
                        text = uiState.dhikr?.title ?: "",
                        style = MaterialTheme.typography.titleMedium,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                },
                navigationIcon = {
                    Box(modifier = Modifier.padding(start = 12.dp, end = 8.dp)) {
                        FilledIconButton(
                            onClick = onNavigateBack,
                            modifier = Modifier.size(40.dp),
                            colors = IconButtonDefaults.filledIconButtonColors(
                                containerColor = MaterialTheme.colorScheme.surfaceContainerHighest,
                                contentColor = MaterialTheme.colorScheme.onSurface,
                            ),
                        ) {
                            Icon(
                                imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                                contentDescription = stringResource(R.string.action_back),
                            )
                        }
                    }
                },
                actions = {
                    TextButton(
                        onClick = onNavigateToCreateGoal,
                        modifier = Modifier.padding(end = 4.dp),
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp),
                    ) {
                        Icon(
                            imageVector = Icons.Default.Add,
                            contentDescription = null,
                            modifier = Modifier.size(16.dp),
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = stringResource(R.string.action_create_goal_short),
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                    if (uiState.dhikr != null) {
                        Box(modifier = Modifier.padding(end = 12.dp)) {
                            FilledIconButton(
                                onClick = { showActions = true },
                                modifier = Modifier.size(40.dp),
                                shape = CircleShape,
                                colors = IconButtonDefaults.filledIconButtonColors(
                                    containerColor = MaterialTheme.colorScheme.surfaceContainerHighest,
                                    contentColor = MaterialTheme.colorScheme.onSurface,
                                ),
                            ) {
                                Icon(
                                    imageVector = Icons.Default.MoreVert,
                                    contentDescription = stringResource(R.string.cd_more_options),
                                )
                            }
                        }
                    }
                },
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) },
    ) { innerPadding ->
        val dhikr = uiState.dhikr

        if (uiState.isLoading || dhikr == null) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
                contentAlignment = Alignment.Center,
            ) {
                if (uiState.isLoading) {
                    CircularProgressIndicator()
                } else {
                    Text(
                        text = stringResource(R.string.dhikr_not_found),
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            return@Scaffold
        }

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            // Arabic text box
            item {
                RitualCard {
                    val quranRef = dhikr.quranRef?.takeIf { it.isValid }
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 34.dp, horizontal = 22.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        if (quranRef != null) {
                            QuranDhikrTextPreview(
                                arabic = dhikr.arabic,
                                ref = quranRef,
                                onShowFull = { onNavigateToQuranReader(dhikr.id) },
                            )
                        } else {
                            Text(
                                text = dhikr.arabic,
                                style = MaterialTheme.typography.headlineMedium.copy(
                                    fontFamily = NotoNaskhArabicFontFamily,
                                ),
                                color = MaterialTheme.colorScheme.onSurface,
                                textAlign = TextAlign.Center,
                                lineHeight = 42.sp,
                            )
                        }
                    }
                }
            }

            item {
                DhikrDetailTabs(
                    showInsights = showInsights,
                    onShowAbout = { showInsights = false },
                    onShowInsights = { showInsights = true },
                )
            }

            if (showInsights) {
                item {
                    val stats = remember(
                        uiState.statsDailyCounts,
                        uiState.statsEffectiveToday,
                        statsRange,
                    ) {
                        DhikrStatsCalculator.calculate(
                            dailyCounts = uiState.statsDailyCounts,
                            effectiveToday = uiState.statsEffectiveToday,
                            range = statsRange,
                        )
                    }
                    DhikrStatsOverviewSection(
                        stats = stats,
                        effectiveToday = uiState.statsEffectiveToday,
                        selectedRange = statsRange,
                        onRangeSelected = { statsRange = it },
                    )
                }
            }

            // Transliteration & Translation
            if (!showInsights) item {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    if (dhikr.transliteration.isNotBlank()) {
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(
                                text = "TRANSLITERATION",
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary,
                                letterSpacing = 1.sp,
                            )
                            Text(
                                text = dhikr.transliteration,
                                style = MaterialTheme.typography.bodyLarge,
                                fontStyle = FontStyle.Italic,
                                color = MaterialTheme.colorScheme.onSurface,
                            )
                        }
                    }
                    val showTranslation = dhikr.translation.isNotBlank() &&
                        dhikr.translation != dhikr.title &&
                        dhikr.translation != dhikr.transliteration
                    if (showTranslation) {
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(
                                text = "MEANING",
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.tertiary,
                                letterSpacing = 1.sp,
                            )
                            Text(
                                text = dhikr.translation,
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                lineHeight = 22.sp,
                            )
                        }
                    }
                }
            }

            // Audio player row — catalog URL, owned audio, or missing owned attachment
            if (!showInsights && (dhikr.audioUrl != null || uiState.ownedAudioFileName != null)) {
                item {
                    if (uiState.ownedAudioMissing) {
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text(
                                text = stringResource(R.string.audio_missing_body),
                                color = MaterialTheme.colorScheme.error,
                                style = MaterialTheme.typography.bodyMedium,
                            )
                            OutlinedButton(onClick = viewModel::removeMissingOwnedAudio) {
                                Text(stringResource(R.string.remove_audio))
                            }
                        }
                    } else {
                        DetailAudioPlayerRow(
                            isPlaying = playerState.dhikrId == dhikr.id && playerState.isPlaying,
                            progress = if (playerState.dhikrId == dhikr.id) playerState.progress else 0f,
                            currentPositionMs = if (playerState.dhikrId == dhikr.id) playerState.currentPositionMs else 0,
                            durationMs = if (playerState.dhikrId == dhikr.id) playerState.durationMs else 0,
                            isDownloaded = dhikr.isDownloaded || uiState.ownedAudioFileName != null,
                            isDownloading = isDownloading,
                            onPlayPause = viewModel::togglePlayback,
                            onDownload = viewModel::downloadAudio,
                        )
                    }
                }
            }

            // Suggested goals section
            val benefitsData = uiState.benefitsData
            if (!showInsights && benefitsData != null && benefitsData.suggestedGoals.isNotEmpty()) {
                item {
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = stringResource(R.string.suggested_goals_title),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                }

                items(benefitsData.suggestedGoals) { suggestion ->
                    val isAdded = viewModel.isSuggestionAlreadyAdded(suggestion)
                    SuggestedGoalCard(
                        suggestion = suggestion,
                        isAdded = isAdded,
                        onAdd = { viewModel.requestAddGoal(suggestion) },
                    )
                }
            }

            item { Spacer(modifier = Modifier.height(80.dp)) }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DhikrActionsBottomSheet(
    isCustom: Boolean,
    onDismiss: () -> Unit,
    onManageTags: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(horizontal = 20.dp)
                .padding(bottom = 20.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(
                text = stringResource(R.string.cd_more_options),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(horizontal = 4.dp, vertical = 12.dp),
            )
            DhikrActionSheetItem(
                label = stringResource(R.string.manage_tags),
                onClick = onManageTags,
            )
            if (isCustom) {
                DhikrActionSheetItem(
                    label = stringResource(R.string.edit_dhikr_title),
                    onClick = onEdit,
                )
                DhikrActionSheetItem(
                    label = stringResource(R.string.delete_dhikr),
                    destructive = true,
                    onClick = onDelete,
                )
            }
        }
    }
}

@Composable
private fun DhikrActionSheetItem(
    label: String,
    destructive: Boolean = false,
    onClick: () -> Unit,
) {
    Surface(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        color = androidx.compose.ui.graphics.Color.Transparent,
        contentColor = if (destructive) {
            MaterialTheme.colorScheme.error
        } else {
            MaterialTheme.colorScheme.onSurface
        },
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.Medium,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
        )
    }
}

@Composable
private fun DhikrDetailTabs(
    showInsights: Boolean,
    onShowAbout: () -> Unit,
    onShowInsights: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(MaterialTheme.colorScheme.surfaceContainerHighest)
            .padding(4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        listOf(
            stringResource(R.string.dhikr_detail_about) to false,
            stringResource(R.string.dhikr_detail_insights) to true,
        ).forEach { (label, insightsTab) ->
            val selected = showInsights == insightsTab
            Tab(
                selected = selected,
                onClick = { if (insightsTab) onShowInsights() else onShowAbout() },
                modifier = Modifier
                    .weight(1f)
                    .height(48.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(
                        if (selected) MaterialTheme.colorScheme.surface
                        else androidx.compose.ui.graphics.Color.Transparent,
                    ),
                selectedContentColor = MaterialTheme.colorScheme.onSurface,
                unselectedContentColor = MaterialTheme.colorScheme.onSurfaceVariant,
                text = {
                    Text(
                        text = label,
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = if (selected) FontWeight.Bold else FontWeight.SemiBold,
                    )
                },
            )
        }
    }
}

@Composable
internal fun DhikrStatsOverviewSection(
    stats: DhikrPracticeStats,
    effectiveToday: java.time.LocalDate,
    selectedRange: DhikrStatsRange,
    onRangeSelected: (DhikrStatsRange) -> Unit,
) {
    val numberFormat = remember { NumberFormat.getIntegerInstance() }
    val rhythmRangeLabel = when (selectedRange) {
        DhikrStatsRange.THIRTY_DAYS -> R.string.dhikr_stats_last_30_effective_days
        DhikrStatsRange.NINETY_DAYS -> R.string.dhikr_stats_last_90_effective_days
        DhikrStatsRange.ALL_TIME -> R.string.dhikr_stats_all_time_period
    }
    val activeDates = remember(stats.dailyCounts) {
        stats.dailyCounts.asSequence()
            .filter { it.count > 0 }
            .map { it.date }
            .toSet()
    }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("dhikr_stats_overview"),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        DhikrStatsRangeSelector(selectedRange, onRangeSelected)
        DhikrStatsPatternSummary(stats)
        DhikrStatsSummaryPanel(stats, numberFormat)

        RitualCard(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(20.dp),
            containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
            tonalElevation = 1.dp,
        ) {
            Column(
                modifier = Modifier.fillMaxWidth().padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(
                        text = stringResource(R.string.dhikr_stats_daily_rhythm),
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                    )
                    Text(
                        text = stringResource(rhythmRangeLabel),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                DhikrStatsBarChart(stats.dailyCounts)
            }
        }

        RitualCard(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(20.dp),
            containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
            tonalElevation = 1.dp,
        ) {
            Column(
                modifier = Modifier.fillMaxWidth().padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(
                    text = stringResource(R.string.dhikr_stats_consistency),
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                )
                StreakSection(
                    currentStreak = stats.currentStreak,
                    activeDates = activeDates,
                    today = effectiveToday,
                    earliestDate = stats.dailyCounts.firstOrNull()?.date,
                )
            }
        }
    }
}

@Composable
private fun DhikrStatsRangeSelector(
    selectedRange: DhikrStatsRange,
    onRangeSelected: (DhikrStatsRange) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(
            text = stringResource(R.string.dhikr_stats_window),
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.weight(1f),
        )
        listOf(
            DhikrStatsRange.THIRTY_DAYS to R.string.dhikr_stats_range_30,
            DhikrStatsRange.NINETY_DAYS to R.string.dhikr_stats_range_90,
            DhikrStatsRange.ALL_TIME to R.string.dhikr_stats_range_all,
        ).forEach { (range, label) ->
            val selected = selectedRange == range
            FilterChip(
                selected = selected,
                onClick = { onRangeSelected(range) },
                shape = CircleShape,
                border = null,
                colors = FilterChipDefaults.filterChipColors(
                    containerColor = MaterialTheme.colorScheme.surfaceContainerHighest,
                    labelColor = MaterialTheme.colorScheme.onSurfaceVariant,
                    selectedContainerColor = MaterialTheme.colorScheme.primary,
                    selectedLabelColor = MaterialTheme.colorScheme.onPrimary,
                ),
                label = {
                    Text(
                        text = stringResource(label),
                        fontWeight = if (selected) FontWeight.Bold else FontWeight.SemiBold,
                    )
                },
            )
        }
    }
}

@Composable
private fun DhikrStatsPatternSummary(stats: DhikrPracticeStats) {
    Card(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
            contentColor = MaterialTheme.colorScheme.onSurface,
        ),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 15.dp),
            verticalArrangement = Arrangement.spacedBy(5.dp),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.primary),
                )
                Text(
                    text = stringResource(R.string.dhikr_stats_pattern_eyebrow),
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 0.8.sp,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
            Text(
                text = stringResource(
                    if (stats.activeDays > 0) R.string.dhikr_stats_pattern_title
                    else R.string.dhikr_stats_empty_title,
                ),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                text = if (stats.activeDays > 0) {
                    pluralStringResource(
                        R.plurals.dhikr_stats_pattern_description,
                        stats.activeDays,
                        stats.activeDays,
                    )
                } else {
                    stringResource(R.string.dhikr_stats_empty_description)
                },
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                lineHeight = 18.sp,
            )
        }
    }
}

@Composable
private fun DhikrStatsSummaryPanel(
    stats: DhikrPracticeStats,
    numberFormat: NumberFormat,
) {
    Card(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                DhikrMetricCell(
                    label = stringResource(R.string.dhikr_stats_recorded_total),
                    value = numberFormat.format(stats.totalCount),
                    detail = stringResource(R.string.dhikr_stats_across_every_goal),
                    highlight = true,
                    modifier = Modifier.weight(1f),
                )
                DhikrStatsMetricDivider()
                DhikrMetricCell(
                    label = stringResource(R.string.dhikr_stats_active_day_average),
                    value = numberFormat.format(stats.activeDayAverage),
                    detail = stringResource(R.string.dhikr_stats_zero_days_excluded),
                    modifier = Modifier.weight(1f),
                )
            }
            HorizontalDivider(
                modifier = Modifier.padding(horizontal = 14.dp),
                color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.72f),
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                DhikrMetricCell(
                    label = stringResource(R.string.dhikr_stats_days_counted),
                    value = numberFormat.format(stats.activeDays),
                    detail = stringResource(R.string.dhikr_stats_presence, stats.presencePercent),
                    modifier = Modifier.weight(1f),
                )
                DhikrStatsMetricDivider()
                DhikrMetricCell(
                    label = stringResource(R.string.dhikr_stats_current_streak),
                    value = pluralStringResource(
                        R.plurals.dhikr_stats_days_value,
                        stats.currentStreak,
                        stats.currentStreak,
                    ),
                    detail = stringResource(R.string.dhikr_stats_effective_day_based),
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

@Composable
private fun DhikrStatsMetricDivider() {
    Box(
        modifier = Modifier
            .width(1.dp)
            .height(68.dp)
            .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.72f)),
    )
}

@Composable
private fun DhikrMetricCell(
    label: String,
    value: String,
    detail: String,
    highlight: Boolean = false,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.padding(horizontal = 14.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            text = value,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.SemiBold,
            color = if (highlight) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
        )
        Text(
            text = detail,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun DhikrStatsBarChart(dailyCounts: List<DhikrDailyCount>) {
    val maxCount = dailyCounts.maxOfOrNull { it.count }?.coerceAtLeast(1L) ?: 1L
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(88.dp)
                .testTag("dhikr_stats_bar_chart"),
            horizontalArrangement = Arrangement.spacedBy(3.dp),
            verticalAlignment = Alignment.Bottom,
        ) {
            dailyCounts.forEachIndexed { index, day ->
                val fraction = if (day.count <= 0) 0.025f else (day.count.toFloat() / maxCount).coerceAtLeast(0.08f)
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight(fraction)
                        .clip(RoundedCornerShape(topStart = 3.dp, topEnd = 3.dp))
                        .background(
                            if (index >= dailyCounts.lastIndex - 6) MaterialTheme.colorScheme.primary
                            else MaterialTheme.colorScheme.primary.copy(alpha = 0.38f),
                        ),
                )
            }
        }
    }
}

@Composable
private fun AddGoalConfirmationDialog(
    suggestion: SuggestedGoal,
    dhikrName: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.add_goal_dialog_title)) },
        text = {
            Column {
                Text(
                    text = stringResource(R.string.add_goal_confirm_msg, dhikrName),
                    style = MaterialTheme.typography.bodyLarge,
                )
                Spacer(modifier = Modifier.height(12.dp))
                Card(
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
                    ),
                    shape = RoundedCornerShape(18.dp),
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(12.dp),
                    ) {
                        Text(
                            text = suggestion.label,
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = formatGoalInfo(suggestion),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
        },
        confirmButton = {
            Button(onClick = onConfirm) {
                Text(stringResource(R.string.action_add_goal), fontWeight = FontWeight.Bold)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.action_cancel))
            }
        },
    )
}

@Composable
private fun DetailAudioPlayerRow(
    isPlaying: Boolean,
    progress: Float,
    currentPositionMs: Long,
    durationMs: Long,
    isDownloaded: Boolean,
    isDownloading: Boolean,
    onPlayPause: () -> Unit,
    onDownload: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(MaterialTheme.colorScheme.surfaceContainerHigh)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Play/Pause button
        FilledIconButton(
            onClick = onPlayPause,
            modifier = Modifier.size(48.dp),
            shape = CircleShape,
        ) {
            Icon(
                imageVector = if (isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                contentDescription = if (isPlaying) stringResource(R.string.cd_pause) else stringResource(R.string.cd_play),
                modifier = Modifier.size(28.dp),
            )
        }

        Spacer(modifier = Modifier.width(12.dp))

        // Progress section
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = stringResource(R.string.recitation_label),
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface,
                letterSpacing = 1.sp,
            )
            Spacer(modifier = Modifier.height(6.dp))
            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(4.dp)
                    .clip(RoundedCornerShape(2.dp)),
                color = MaterialTheme.colorScheme.primary,
                trackColor = MaterialTheme.colorScheme.outlineVariant,
            )
            Spacer(modifier = Modifier.height(4.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(
                    text = formatTime(currentPositionMs),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    text = formatTime(durationMs),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        // Download button
        Spacer(modifier = Modifier.width(8.dp))
        if (isDownloaded) {
            Icon(
                imageVector = Icons.Default.Check,
                contentDescription = stringResource(R.string.cd_downloaded),
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier
                    .size(40.dp)
                    .padding(8.dp),
            )
        } else if (isDownloading) {
            CircularProgressIndicator(
                modifier = Modifier
                    .size(40.dp)
                    .padding(8.dp),
                strokeWidth = 2.dp,
            )
        } else {
            IconButton(onClick = onDownload) {
                Icon(
                    imageVector = Icons.Default.Download,
                    contentDescription = stringResource(R.string.cd_download_audio),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun SuggestedGoalCard(
    suggestion: SuggestedGoal,
    isAdded: Boolean,
    onAdd: () -> Unit,
) {
    RitualCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(22.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = suggestion.label,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = suggestion.description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    lineHeight = 18.sp,
                )
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = formatGoalInfo(suggestion),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Spacer(modifier = Modifier.width(12.dp))
            if (isAdded) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 8.dp),
                ) {
                    Icon(
                        imageVector = Icons.Default.CheckCircle,
                        contentDescription = stringResource(R.string.cd_goal_added),
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(18.dp),
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = stringResource(R.string.action_added),
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
            } else {
                Button(
                    onClick = onAdd,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.secondaryContainer,
                        contentColor = MaterialTheme.colorScheme.onSecondaryContainer,
                    ),
                    shape = RoundedCornerShape(12.dp),
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                ) {
                    Icon(
                        imageVector = Icons.Default.Add,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp),
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = stringResource(R.string.action_add),
                        fontWeight = FontWeight.Bold,
                    )
                }
            }
        }
    }
}

@Composable
private fun formatGoalInfo(suggestion: SuggestedGoal): String {
    val typeLabel = if (suggestion.isOneTime) {
        stringResource(R.string.goal_type_one_time)
    } else {
        when (suggestion.frequencyType) {
            FrequencyType.DAILY -> stringResource(R.string.goal_type_daily)
            FrequencyType.WEEKLY -> stringResource(R.string.goal_type_daily) // fallback
            else -> stringResource(R.string.goal_type_daily)
        }
    }
    val scope = if (suggestion.isOneTime) {
        stringResource(R.string.goal_info_total)
    } else {
        stringResource(R.string.goal_info_per_day)
    }
    return "$typeLabel \u00b7 ${formatNumber(suggestion.targetCount)} $scope"
}

private fun formatNumber(value: Int): String {
    return "%,d".format(value)
}

private fun formatTime(ms: Long): String {
    if (ms <= 0) return "0:00"
    val totalSeconds = ms / 1000
    val minutes = totalSeconds / 60
    val seconds = totalSeconds % 60
    return "$minutes:%02d".format(seconds)
}
