package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.EaseInOutCubic
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.outlined.SelfImprovement
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.core.content.ContextCompat
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualCard
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualEmptyState
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualIconTile
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualMetricChip
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalCreationMode
import app.awrad.awrad_dhikrgoalstracker.ui.theme.NotoNaskhArabicFontFamily
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme

/** Ordering used only to pick the slide direction between create-goal screens. */
private fun goalModeDepth(mode: GoalCreationMode): Int = when (mode) {
    GoalCreationMode.SelectDhikr -> 0
    GoalCreationMode.SelectShape -> 1
    GoalCreationMode.SimpleTarget -> 2
    GoalCreationMode.Advanced -> 2
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateGoalScreen(
    onGoalCreated: (AwradId) -> Unit,
    onNavigateBack: () -> Unit,
    onNavigateToQuranReader: (AwradId) -> Unit = {},
    viewModel: CreateGoalViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val audioState by viewModel.audioState.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val notificationPermissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
    ) { /* granted or denied — goal creation remains user-driven */ }

    fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    LaunchedEffect(uiState.createdGoalId) {
        uiState.createdGoalId?.let(onGoalCreated)
    }

    LaunchedEffect(uiState.draft?.extras?.notificationEnabled) {
        if (uiState.draft?.extras?.notificationEnabled == true) {
            requestNotificationPermissionIfNeeded()
        }
    }

    BackHandler {
        val shouldExit = viewModel.navigateBack()
        if (shouldExit) onNavigateBack()
    }

    val title = when (uiState.mode) {
        GoalCreationMode.SelectShape -> stringResource(R.string.create_goal_shape_appbar)
        GoalCreationMode.SelectDhikr -> stringResource(R.string.create_goal_select_dhikr)
        GoalCreationMode.SimpleTarget -> stringResource(R.string.create_goal_simple_appbar)
        GoalCreationMode.Advanced -> stringResource(R.string.create_goal_advanced_appbar)
    }

    Scaffold(
        containerColor = androidx.compose.ui.graphics.Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(title) },
                navigationIcon = {
                    Box(modifier = Modifier.padding(start = 12.dp, end = 8.dp)) {
                        FilledIconButton(
                            onClick = {
                                val shouldExit = viewModel.navigateBack()
                                if (shouldExit) onNavigateBack()
                            },
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
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = if (isAwradDarkTheme()) {
                        androidx.compose.ui.graphics.Color.Transparent
                    } else {
                        MaterialTheme.colorScheme.surface
                    },
                    navigationIconContentColor = MaterialTheme.colorScheme.onSurface,
                    titleContentColor = MaterialTheme.colorScheme.onSurface,
                    actionIconContentColor = MaterialTheme.colorScheme.onSurface,
                ),
                windowInsets = WindowInsets.statusBars,
            )
        },
        contentWindowInsets = WindowInsets(0),
    ) { padding ->
            AnimatedContent(
                targetState = uiState.mode,
                transitionSpec = {
                    val forward = goalModeDepth(targetState) >= goalModeDepth(initialState)
                    if (forward) {
                        (slideInHorizontally(tween(260, easing = EaseInOutCubic)) { it / 2 } + fadeIn(tween(220))) togetherWith
                            (slideOutHorizontally(tween(260, easing = EaseInOutCubic)) { -it / 4 } + fadeOut(tween(180)))
                    } else {
                        (slideInHorizontally(tween(260, easing = EaseInOutCubic)) { -it / 4 } + fadeIn(tween(220))) togetherWith
                            (slideOutHorizontally(tween(260, easing = EaseInOutCubic)) { it / 2 } + fadeOut(tween(180)))
                    }
                },
                modifier = Modifier.fillMaxSize().padding(padding),
                label = "GoalCreationMode",
            ) { mode ->
                when (mode) {
                    GoalCreationMode.SelectShape -> {
                        SelectGoalShapeStep(
                            onSelectShape = viewModel::selectShape,
                            onAdvanced = viewModel::enterAdvanced,
                        )
                    }
                    GoalCreationMode.SelectDhikr -> {
                        SelectDhikrStep(
                            dhikrs = uiState.filteredDhikrs,
                            searchQuery = uiState.searchQuery,
                            onSearchChange = viewModel::onSearchQueryChange,
                            onSelect = viewModel::selectDhikr,
                        )
                    }
                    GoalCreationMode.SimpleTarget -> {
                        val draft = uiState.draft ?: return@AnimatedContent
                        SimpleTargetPane(
                            dhikr = uiState.selectedDhikr,
                            audioState = audioState,
                            draft = draft,
                            validation = uiState.validation,
                            isCreating = uiState.isCreating,
                            canChangeDhikr = !uiState.isDhikrLocked,
                            onTogglePlayback = viewModel::togglePlayback,
                            onShowFullQuran = onNavigateToQuranReader,
                            onChangeDhikr = viewModel::openDhikrPicker,
                            onTargetChange = viewModel::updateTargetDraft,
                            onCreate = viewModel::createGoal,
                        )
                    }
                    GoalCreationMode.Advanced -> {
                        val dhikr = uiState.selectedDhikr ?: return@AnimatedContent
                        val draft = uiState.draft ?: return@AnimatedContent
                        GoalComposerPane(
                            dhikr = dhikr,
                            audioState = audioState,
                            draft = draft,
                            validation = uiState.validation,
                            isCreating = uiState.isCreating,
                            canChangeDhikr = !uiState.isDhikrLocked,
                            onTogglePlayback = viewModel::togglePlayback,
                            onShowFullQuran = onNavigateToQuranReader,
                            onChangeDhikr = viewModel::openDhikrPicker,
                            onSelectPreset = {},
                            onTargetChange = viewModel::updateTargetDraft,
                            onFrequencyChange = viewModel::updateFrequencyDraft,
                            onExtrasChange = viewModel::updateExtras,
                            onDraftChange = viewModel::updateDraft,
                            onCreate = viewModel::createGoal,
                            showTypeSelector = false,
                        )
                    }
                }
            }
    }
}

@Composable
private fun SelectDhikrStep(
    dhikrs: List<Dhikr>,
    searchQuery: String,
    onSearchChange: (String) -> Unit,
    onSelect: (Dhikr) -> Unit,
    modifier: Modifier = Modifier,
) {
    val searchContainerColor =
        if (isAwradDarkTheme()) MaterialTheme.colorScheme.surfaceContainerHigh else MaterialTheme.colorScheme.surface
    Column(modifier = modifier.fillMaxSize()) {
        OutlinedTextField(
            value = searchQuery,
            onValueChange = onSearchChange,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp),
            placeholder = { Text(stringResource(R.string.create_goal_search_hint)) },
            leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
            singleLine = true,
            shape = RoundedCornerShape(18.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedContainerColor = searchContainerColor,
                unfocusedContainerColor = searchContainerColor,
                focusedBorderColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.56f),
                unfocusedBorderColor = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.72f),
            ),
        )
        LazyColumn(
            contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            item {
                Column(modifier = Modifier.padding(bottom = 6.dp)) {
                    Text(
                        text = stringResource(R.string.create_goal_choose_dhikr_title),
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Text(
                        text = stringResource(R.string.create_goal_choose_dhikr_subtitle),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
            }
            if (dhikrs.isEmpty()) {
                item {
                    RitualEmptyState(
                        title = stringResource(R.string.create_goal_no_dhikr_found),
                        body = stringResource(R.string.create_goal_no_dhikr_found_body),
                        icon = Icons.Outlined.SelfImprovement,
                    )
                }
            }
            items(dhikrs, key = { it.id }) { dhikr ->
                DhikrPickerRow(dhikr = dhikr, onSelect = { onSelect(dhikr) })
            }
        }
    }
}

@Composable
private fun DhikrPickerRow(
    dhikr: Dhikr,
    onSelect: () -> Unit,
    modifier: Modifier = Modifier,
) {
    RitualCard(modifier = modifier.fillMaxWidth(), onClick = onSelect) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 14.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
        ) {
            RitualIconTile(icon = Icons.Outlined.SelfImprovement)
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = dhikr.arabic,
                    fontFamily = NotoNaskhArabicFontFamily,
                    style = MaterialTheme.typography.titleLarge,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = dhikr.transliteration.ifBlank { dhikr.title },
                    style = MaterialTheme.typography.titleSmall,
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(top = 3.dp),
                )
                Text(
                    text = dhikr.translation.ifBlank { dhikr.title },
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
            RitualMetricChip(text = stringResource(R.string.action_choose))
        }
    }
}
