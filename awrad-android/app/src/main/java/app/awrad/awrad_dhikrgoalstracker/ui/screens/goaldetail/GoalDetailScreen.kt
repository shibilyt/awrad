package app.awrad.awrad_dhikrgoalstracker.ui.screens.goaldetail

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.windowInsetsTopHeight
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.outlined.AccessTime
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.Event
import androidx.compose.material.icons.outlined.Flag
import androidx.compose.material.icons.outlined.KeyboardArrowDown
import androidx.compose.material.icons.outlined.Layers
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.Rule
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material.icons.outlined.TrackChanges
import androidx.compose.material.icons.outlined.Tune
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.CalendarSystem
import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalReminder
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.RecurrenceFrequency
import app.awrad.awrad_dhikrgoalstracker.data.model.ReminderType
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import app.awrad.awrad_dhikrgoalstracker.domain.usecase.GoalProgressSummary
import app.awrad.awrad_dhikrgoalstracker.ui.components.AwradStatusBarStyle
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualPrimaryButton
import app.awrad.awrad_dhikrgoalstracker.ui.screens.counting.DhikrFullTextBottomSheet
import app.awrad.awrad_dhikrgoalstracker.ui.screens.counting.nextCountingDhikrLineSpacing
import app.awrad.awrad_dhikrgoalstracker.ui.screens.counting.nextCountingDhikrTextScale
import app.awrad.awrad_dhikrgoalstracker.ui.screens.counting.previousCountingDhikrLineSpacing
import app.awrad.awrad_dhikrgoalstracker.ui.screens.counting.previousCountingDhikrTextScale
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.localizedName
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.localizedTitle
import app.awrad.awrad_dhikrgoalstracker.ui.theme.AwradDhikrGoalsTrackerTheme
import app.awrad.awrad_dhikrgoalstracker.ui.theme.NotoNaskhArabicFontFamily
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme
import app.awrad.awrad_dhikrgoalstracker.util.GoalProgressCalculator
import java.time.DayOfWeek
import java.time.LocalDate

@Composable
fun GoalDetailScreen(
    goalId: AwradId,
    onNavigateBack: () -> Unit,
    onNavigateToCounting: () -> Unit,
    onNavigateToEdit: () -> Unit,
    onNavigateToEditSchedule: () -> Unit,
    onNavigateToEditReminders: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: GoalDetailViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    GoalDetailContent(
        uiState = uiState,
        onNavigateBack = onNavigateBack,
        onNavigateToCounting = onNavigateToCounting,
        onNavigateToEdit = onNavigateToEdit,
        onNavigateToEditSchedule = onNavigateToEditSchedule,
        onNavigateToEditReminders = onNavigateToEditReminders,
        modifier = modifier,
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun GoalDetailContent(
    uiState: GoalDetailUiState,
    onNavigateBack: () -> Unit,
    onNavigateToCounting: () -> Unit,
    onNavigateToEdit: () -> Unit,
    onNavigateToEditSchedule: () -> Unit,
    onNavigateToEditReminders: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        modifier = modifier,
        containerColor = Color.Transparent,
        contentWindowInsets = WindowInsets(0),
        topBar = {
            GoalDetailTopBar(
                title = stringResource(R.string.goal_details_title),
                onNavigateBack = onNavigateBack,
            )
        },
    ) { padding ->
        val goal = uiState.goal
        when {
            uiState.isLoading -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding),
                    contentAlignment = Alignment.Center,
                ) {
                    CircularProgressIndicator()
                }
            }
            goal == null -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding)
                        .padding(24.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = stringResource(R.string.goal_details_missing),
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            else -> {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding),
                    contentPadding = PaddingValues(horizontal = 20.dp, vertical = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(28.dp),
                ) {
                    item {
                        GoalHeroCard(
                            goal = goal,
                            dhikr = uiState.dhikr,
                            progress = uiState.progress,
                            canContinueCounting = uiState.canContinueCounting,
                            onNavigateToCounting = onNavigateToCounting,
                        )
                    }

                    item {
                        GoalOverviewSection(
                            goal = goal,
                            onEditCounting = onNavigateToEdit,
                            onEditSchedule = onNavigateToEditSchedule,
                        )
                    }

                    item {
                        SessionsSection(
                            goal = goal,
                            slotCountsToday = uiState.slotCountsToday,
                            slotCountsAllTime = uiState.slotCountsAllTime,
                            onEdit = onNavigateToEditSchedule,
                        )
                    }

                    item {
                        RemindersSection(goal = goal, onEdit = onNavigateToEditReminders)
                    }
                }
            }
        }
    }
}

@Composable
private fun GoalDetailTopBar(
    title: String,
    onNavigateBack: () -> Unit,
) {
    val containerColor = if (isAwradDarkTheme()) Color.Transparent else MaterialTheme.colorScheme.surfaceContainerHigh
    AwradStatusBarStyle(color = MaterialTheme.colorScheme.background)
    Surface(
        color = containerColor,
        contentColor = MaterialTheme.colorScheme.onSurface,
    ) {
        Column {
            Spacer(modifier = Modifier.windowInsetsTopHeight(WindowInsets.statusBars))
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp)
                    .padding(start = 4.dp, end = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
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
                            imageVector = Icons.AutoMirrored.Rounded.ArrowBack,
                            contentDescription = stringResource(R.string.action_back),
                        )
                    }
                }
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

@Composable
private fun GoalHeroCard(
    goal: Goal,
    dhikr: Dhikr?,
    progress: GoalProgressSummary?,
    canContinueCounting: Boolean,
    onNavigateToCounting: () -> Unit,
) {
    val colorScheme = MaterialTheme.colorScheme
    val progressCount = progress?.progressCount ?: 0L
    val targetCount = progress?.targetCount ?: GoalProgressCalculator.getTargetCount(goal)
    val fraction = progress?.progress ?: 0f
    val isComplete = targetCount > 0 && fraction >= 1f
    val remaining = progress?.remainingCount ?: (targetCount - progressCount).coerceAtLeast(0L)
    val displayTitle = dhikr?.transliteration?.ifBlank { dhikr.title }.orEmpty().ifBlank {
        stringResource(R.string.goal_details_goal_fallback)
    }
    var showFullDhikr by remember { mutableStateOf(false) }
    var isArabicOverflowing by remember { mutableStateOf(false) }
    var textScale by remember { mutableStateOf(1f) }
    var lineSpacing by remember { mutableStateOf(1f) }

    val animatedProgress by animateFloatAsState(
        targetValue = fraction.coerceIn(0f, 1f),
        animationSpec = tween(durationMillis = 700, easing = FastOutSlowInEasing),
        label = "goalDetailProgress",
    )

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(
                text = displayTitle,
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = colorScheme.onSurface,
            )
            dhikr?.arabic?.takeIf { it.isNotBlank() }?.let { arabic ->
                GoalDhikrPreview(
                    arabic = arabic,
                    isOverflowing = isArabicOverflowing,
                    onTextOverflowChanged = { isArabicOverflowing = it },
                    onShowFullDhikr = { showFullDhikr = true },
                )
            }
            dhikr?.translation
                ?.takeIf { it.isNotBlank() && !it.equals(displayTitle, ignoreCase = true) }
                ?.let { translation ->
                    Text(
                        text = translation,
                        style = MaterialTheme.typography.bodyMedium,
                        color = colorScheme.onSurfaceVariant,
                    )
                }
        }

        Surface(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(22.dp),
            color = colorScheme.primaryContainer.copy(alpha = if (isAwradDarkTheme()) 0.28f else 0.38f),
        ) {
            Column(
                modifier = Modifier.padding(horizontal = 18.dp, vertical = 17.dp),
                verticalArrangement = Arrangement.spacedBy(13.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
                        Text(
                            text = stringResource(R.string.goal_details_today_label),
                            style = MaterialTheme.typography.labelLarge,
                            color = colorScheme.onSurfaceVariant,
                        )
                        Text(
                            text = if (targetCount > 0) {
                                stringResource(R.string.goal_details_progress_fraction, progressCount, targetCount)
                            } else {
                                stringResource(R.string.goal_details_progress_count_only, progressCount)
                            },
                            style = MaterialTheme.typography.headlineSmall,
                            fontWeight = FontWeight.Bold,
                            color = colorScheme.onSurface,
                        )
                    }
                    when {
                        isComplete -> HeroStatusChip(
                            text = stringResource(R.string.goal_details_complete_label),
                            icon = Icons.Rounded.Check,
                            emphasised = true,
                        )
                        targetCount > 0 && remaining > 0 -> HeroStatusChip(
                            text = stringResource(R.string.goal_details_remaining_count, remaining),
                            icon = null,
                            emphasised = false,
                        )
                    }
                }
                if (targetCount > 0) {
                    LinearProgressIndicator(
                        progress = { animatedProgress },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(8.dp)
                            .clip(RoundedCornerShape(12.dp)),
                        color = colorScheme.primary,
                        trackColor = colorScheme.primary.copy(alpha = 0.14f),
                    )
                }
            }
        }

        RitualPrimaryButton(
            text = stringResource(
                if (canContinueCounting) {
                    R.string.goal_details_continue_counting
                } else {
                    R.string.goal_details_view_counting
                },
            ),
            onClick = onNavigateToCounting,
            enabled = true,
            leadingIcon = Icons.Rounded.PlayArrow,
        )
    }

    if (showFullDhikr && dhikr != null) {
        DhikrFullTextBottomSheet(
            arabic = dhikr.arabic,
            quranRef = dhikr.quranRef,
            textScale = textScale,
            lineSpacing = lineSpacing,
            isAudioMode = false,
            canManualCount = false,
            onDecreaseTextSize = { textScale = previousCountingDhikrTextScale(textScale) },
            onIncreaseTextSize = { textScale = nextCountingDhikrTextScale(textScale) },
            onDecreaseLineSpacing = { lineSpacing = previousCountingDhikrLineSpacing(lineSpacing) },
            onIncreaseLineSpacing = { lineSpacing = nextCountingDhikrLineSpacing(lineSpacing) },
            onCount = {},
            onDismiss = { showFullDhikr = false },
            showCountButton = false,
        )
    }
}

@Composable
private fun GoalDhikrPreview(
    arabic: String,
    isOverflowing: Boolean,
    onTextOverflowChanged: (Boolean) -> Unit,
    onShowFullDhikr: () -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface,
        ),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.2f)),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.horizontalGradient(
                        listOf(
                            MaterialTheme.colorScheme.surface,
                            MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.26f),
                            MaterialTheme.colorScheme.surfaceContainer,
                        ),
                    ),
                )
                .padding(vertical = 14.dp, horizontal = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = arabic,
                style = MaterialTheme.typography.titleLarge.copy(
                    fontFamily = NotoNaskhArabicFontFamily,
                ),
                color = MaterialTheme.colorScheme.onSurface,
                textAlign = TextAlign.Center,
                lineHeight = 34.sp,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                onTextLayout = { onTextOverflowChanged(it.hasVisualOverflow) },
                modifier = Modifier.fillMaxWidth(),
            )
            if (isOverflowing) {
                TextButton(onClick = onShowFullDhikr) {
                    Text(
                        text = stringResource(R.string.counting_see_full),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.secondary,
                    )
                }
            }
        }
    }
}

@Composable
private fun HeroStatusChip(
    text: String,
    icon: ImageVector?,
    emphasised: Boolean,
) {
    val colorScheme = MaterialTheme.colorScheme
    val container = if (emphasised) {
        colorScheme.primary.copy(alpha = 0.16f)
    } else {
        colorScheme.surfaceVariant.copy(alpha = 0.6f)
    }
    val content = if (emphasised) colorScheme.primary else colorScheme.onSurfaceVariant
    Surface(
        shape = RoundedCornerShape(14.dp),
        color = container,
        border = BorderStroke(1.dp, content.copy(alpha = 0.2f)),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            if (icon != null) {
                Icon(icon, contentDescription = null, tint = content, modifier = Modifier.size(16.dp))
            }
            Text(
                text = text,
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
                color = content,
            )
        }
    }
}

@Composable
private fun GoalOverviewSection(
    goal: Goal,
    onEditCounting: () -> Unit,
    onEditSchedule: () -> Unit,
) {
    val advancedItems = listOf(
        DetailItem(Icons.Outlined.TrackChanges, stringResource(R.string.goal_details_progress_scope), progressScopeSummary(goal.targetPolicy)),
        DetailItem(Icons.Outlined.Shield, stringResource(R.string.goal_details_cap_behavior), capBehaviorSummary(goal.capBehavior)),
        DetailItem(Icons.Outlined.Flag, stringResource(R.string.goal_details_completion), completionSummary(goal)),
    )

    val scheduleItems = listOf(
        DetailItem(Icons.Outlined.CalendarMonth, stringResource(R.string.goal_details_repeats), scheduleSummary(goal)),
        DetailItem(Icons.Outlined.AccessTime, stringResource(R.string.goal_details_timing), timingSummary(goal)),
        DetailItem(Icons.Outlined.Event, stringResource(R.string.goal_details_duration), durationSummary(goal)),
    )

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SectionLabel(stringResource(R.string.goal_details_overview_section))
        DetailCard {
            DetailSubsectionHeader(
                title = stringResource(R.string.goal_details_counting_section),
                onEdit = onEditCounting,
            )
            DetailInfoRow(
                DetailItem(
                    icon = Icons.Outlined.Tune,
                    label = stringResource(R.string.goal_details_count_rule),
                    value = countRuleSummary(goal),
                ),
            )
            RowDivider()
            DetailSubsectionHeader(
                title = stringResource(R.string.goal_details_schedule_section),
                onEdit = onEditSchedule,
            )
            scheduleItems.forEachIndexed { index, item ->
                DetailInfoRow(item)
                if (index != scheduleItems.lastIndex) RowDivider()
            }
        }
        AdvancedDisclosure(items = advancedItems)
    }
}

@Composable
private fun DetailSubsectionHeader(title: String, onEdit: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 16.dp, end = 10.dp, top = 10.dp, bottom = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
        )
        IconButton(onClick = onEdit, modifier = Modifier.size(40.dp)) {
            Icon(
                imageVector = Icons.Outlined.Edit,
                contentDescription = stringResource(R.string.goal_details_edit_action),
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(19.dp),
            )
        }
    }
}

@Composable
private fun AdvancedDisclosure(items: List<DetailItem>) {
    var expanded by remember { mutableStateOf(false) }
    val rotation by animateFloatAsState(
        targetValue = if (expanded) 180f else 0f,
        animationSpec = tween(durationMillis = 240, easing = FastOutSlowInEasing),
        label = "advancedChevron",
    )
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        DetailCard {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { expanded = !expanded }
                    .padding(horizontal = 16.dp, vertical = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                DetailIconTile(Icons.Outlined.Tune)
                Text(
                    text = stringResource(R.string.goal_details_advanced),
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.weight(1f),
                )
                Icon(
                    imageVector = Icons.Outlined.KeyboardArrowDown,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.rotate(rotation),
                )
            }
            AnimatedVisibility(
                visible = expanded,
                enter = expandVertically() + fadeIn(),
                exit = shrinkVertically() + fadeOut(),
            ) {
                Column {
                    RowDivider()
                    items.forEachIndexed { index, item ->
                        DetailInfoRow(item)
                        if (index != items.lastIndex) RowDivider()
                    }
                }
            }
        }
    }
}

@Composable
private fun SessionsSection(
    goal: Goal,
    slotCountsToday: Map<AwradId, Long>,
    slotCountsAllTime: Map<AwradId, Long>,
    onEdit: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SectionHeader(stringResource(R.string.goal_details_slots_section), onEdit = onEdit)
        if (goal.activeSlots.isEmpty()) {
            DetailCard {
                DetailInfoRow(
                    DetailItem(
                        icon = Icons.Outlined.Layers,
                        label = stringResource(R.string.slot_anytime),
                        value = stringResource(R.string.goal_details_no_slot_progress),
                    ),
                )
            }
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                goal.activeSlots.sortedBy { it.sortOrder }.forEach { slot ->
                    SlotDetailCard(slot = slot, count = slotCountsToday[slot.id] ?: 0L)
                }
            }
        }

        val archivedSlots = goal.archivedSlots
            .sortedBy { it.sortOrder }
            .filter { (slotCountsAllTime[it.id] ?: 0L) > 0L }
        if (archivedSlots.isNotEmpty()) {
            Spacer(modifier = Modifier.height(2.dp))
            SectionLabel(stringResource(R.string.goal_details_archived_slots_section))
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                archivedSlots.forEach { slot ->
                    SlotDetailCard(slot = slot, count = slotCountsAllTime[slot.id] ?: 0L)
                }
            }
        }
    }
}

@Composable
private fun SlotDetailCard(slot: GoalSlot, count: Long) {
    val colorScheme = MaterialTheme.colorScheme
    val target = slot.targetCount
    val fraction = if (target != null && target > 0) {
        (count.toFloat() / target).coerceIn(0f, 1f)
    } else {
        0f
    }
    val animatedProgress by animateFloatAsState(
        targetValue = fraction,
        animationSpec = tween(durationMillis = 700),
        label = "slotProgress",
    )
    val countText = if (target != null && target > 0) {
        stringResource(R.string.goal_details_progress_fraction, count, target)
    } else {
        stringResource(R.string.goal_details_progress_count_only, count)
    }
    val subtitle = listOf(slotCountRuleSummary(slot), slotTimingSubtitle(slot))
        .filter { it.isNotBlank() }
        .joinToString(" · ")

    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        color = colorScheme.surfaceContainerLow,
        border = BorderStroke(1.dp, colorScheme.outlineVariant.copy(alpha = 0.5f)),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.Top,
            ) {
                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        text = slotTitle(slot),
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = colorScheme.onSurface,
                    )
                    if (subtitle.isNotBlank()) {
                        Text(
                            text = subtitle,
                            style = MaterialTheme.typography.bodySmall,
                            color = colorScheme.onSurfaceVariant,
                        )
                    }
                }
                Text(
                    text = countText,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = colorScheme.onSurface,
                )
            }
            if (target != null && target > 0) {
                LinearProgressIndicator(
                    progress = { animatedProgress },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(8.dp)
                        .clip(RoundedCornerShape(12.dp)),
                    color = colorScheme.secondary,
                    trackColor = colorScheme.primaryContainer.copy(alpha = 0.55f),
                )
            }
        }
    }
}

@Composable
private fun RemindersSection(goal: Goal, onEdit: () -> Unit) {
    val reminders = goal.reminders.filter { it.enabled }.sortedBy { it.sortOrder }
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SectionHeader(stringResource(R.string.goal_details_reminders_section), onEdit = onEdit)
        DetailCard {
            if (reminders.isEmpty()) {
                DetailInfoRow(
                    DetailItem(
                        icon = Icons.Outlined.Notifications,
                        label = stringResource(R.string.goal_details_reminders),
                        value = stringResource(R.string.goal_summary_off),
                    ),
                )
            } else {
                reminders.forEachIndexed { index, reminder ->
                    DetailInfoRow(
                        DetailItem(
                            icon = Icons.Outlined.Notifications,
                            label = stringResource(R.string.goal_details_reminder_number, index + 1),
                            value = reminderSummary(reminder, goal),
                        ),
                    )
                    if (index != reminders.lastIndex) RowDivider()
                }
            }
        }
    }
}

private data class DetailItem(
    val icon: ImageVector,
    val label: String,
    val value: String,
)

@Composable
private fun SectionLabel(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.labelLarge,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        letterSpacing = 0.6.sp,
        modifier = Modifier.padding(start = 4.dp),
    )
}

@Composable
private fun SectionHeader(title: String, onEdit: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SectionLabel(title)
        Spacer(modifier = Modifier.weight(1f))
        EditChip(onClick = onEdit)
    }
}

@Composable
private fun EditChip(onClick: () -> Unit) {
    val colorScheme = MaterialTheme.colorScheme
    Surface(
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(50),
        color = colorScheme.primary.copy(alpha = 0.1f),
    ) {
        Row(
            modifier = Modifier.padding(start = 10.dp, end = 12.dp, top = 6.dp, bottom = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(5.dp),
        ) {
            Icon(
                imageVector = Icons.Outlined.Edit,
                contentDescription = null,
                tint = colorScheme.primary,
                modifier = Modifier.size(15.dp),
            )
            Text(
                text = stringResource(R.string.goal_details_edit_action),
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
                color = colorScheme.primary,
            )
        }
    }
}

@Composable
private fun DetailCard(content: @Composable () -> Unit) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(20.dp),
        color = MaterialTheme.colorScheme.surfaceContainerLow,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            content()
        }
    }
}

@Composable
private fun DetailInfoRow(item: DetailItem) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        DetailIconTile(item.icon)
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
            Text(
                text = item.label,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                text = item.value,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface,
            )
        }
    }
}

@Composable
private fun DetailIconTile(icon: ImageVector) {
    val colorScheme = MaterialTheme.colorScheme
    Box(
        modifier = Modifier
            .size(38.dp)
            .background(colorScheme.primary.copy(alpha = 0.1f), RoundedCornerShape(11.dp)),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = colorScheme.primary,
            modifier = Modifier.size(20.dp),
        )
    }
}

@Composable
private fun RowDivider() {
    HorizontalDivider(
        modifier = Modifier.padding(start = 16.dp),
        color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f),
    )
}

@Composable
private fun scheduleSummary(goal: Goal): String =
    when (val frequency = goal.recurrence.frequency) {
        RecurrenceFrequency.DAILY -> stringResource(R.string.goal_summary_schedule_daily)
        RecurrenceFrequency.WEEKLY -> goal.recurrence.weekdays
            .takeIf { it.isNotEmpty() }
            ?.sortedBy { it.value }
            ?.joinToString(", ") { it.shortName() }
            ?: stringResource(R.string.goal_summary_schedule_no_weekdays)
        RecurrenceFrequency.MONTHLY -> if (goal.recurrence.monthDays.isEmpty()) {
            stringResource(R.string.goal_summary_schedule_monthly, goal.recurrence.calendar.displayName())
        } else {
            stringResource(
                R.string.goal_summary_schedule_monthly_on,
                goal.recurrence.calendar.displayName(),
                goal.recurrence.monthDays.sorted().joinToString(", "),
            )
        }
        RecurrenceFrequency.INTERVAL -> stringResource(
            R.string.goal_summary_schedule_interval,
            goal.recurrence.intervalDays ?: 1,
        )
        RecurrenceFrequency.YEARLY -> stringResource(
            R.string.goal_summary_schedule_yearly,
            goal.recurrence.calendar.displayName(),
            goal.recurrence.month ?: 0,
            goal.recurrence.monthDays.sorted().joinToString(", ")
                .ifBlank { stringResource(R.string.goal_summary_not_set) },
        )
        RecurrenceFrequency.SEASON -> goal.recurrence.seasonTemplateCode?.localizedName()
            ?: stringResource(R.string.schedule_season)
        RecurrenceFrequency.SPECIFIC_DATES -> goal.recurrence.specificDates
            .takeIf { it.isNotEmpty() }
            ?.joinToString(", ") { it.date?.toString() ?: "${it.calendar.displayName()} ${it.month}/${it.dayOfMonth}" }
            ?: stringResource(R.string.goal_summary_schedule_no_dates)
    }

@Composable
private fun progressScopeSummary(policy: TargetPolicy): String =
    when (policy) {
        TargetPolicy.PER_DUE_DATE -> stringResource(R.string.goal_details_scope_due_date)
        TargetPolicy.CUMULATIVE_TOTAL -> stringResource(R.string.goal_details_scope_lifetime)
        TargetPolicy.PERIOD_TOTAL -> stringResource(R.string.goal_details_scope_period)
        TargetPolicy.NONE -> stringResource(R.string.goal_summary_no_target)
    }

@Composable
private fun timingSummary(goal: Goal): String {
    val slots = goal.activeSlots
    return when {
        slots.isEmpty() -> stringResource(R.string.goal_summary_slots_anytime)
        slots.size == 1 && slots.single().slotType == GoalSlotType.ANYTIME ->
            stringResource(R.string.goal_summary_slots_anytime)
        slots.all { it.slotType == GoalSlotType.PRAYER } ->
            pluralStringResource(R.plurals.goal_details_timing_prayer_slots, slots.size, slots.size)
        slots.all { it.slotType == GoalSlotType.TIME_WINDOW } ->
            pluralStringResource(R.plurals.goal_summary_slots_time_count, slots.size, slots.size)
        else -> pluralStringResource(R.plurals.goal_details_timing_mixed_slots, slots.size, slots.size)
    }
}

@Composable
private fun countRuleSummary(goal: Goal): String {
    val target = GoalProgressCalculator.getTargetCount(goal).takeIf { it > 0 }
    return countRuleSummary(
        minimum = goal.minimumStreakCount,
        target = target,
        maximum = goal.maximumCount,
        capBehavior = goal.capBehavior,
        daily = goal.recurrence.frequency == RecurrenceFrequency.DAILY,
        fallbackNoTarget = stringResource(R.string.goal_summary_no_target),
    )
}

@Composable
private fun slotCountRuleSummary(slot: GoalSlot): String =
    countRuleSummary(
        minimum = slot.minimumCount,
        target = slot.targetCount,
        maximum = slot.maximumCount,
        capBehavior = slot.capBehavior,
        fallbackNoTarget = stringResource(R.string.goal_details_no_slot_target),
    )

@Composable
private fun countRuleSummary(
    minimum: Int?,
    target: Int?,
    maximum: Int?,
    capBehavior: CountCapBehavior,
    daily: Boolean = false,
    fallbackNoTarget: String,
): String =
    when {
        target != null && maximum != null && target == maximum && capBehavior == CountCapBehavior.BlockAtMaximum ->
            stringResource(
                if (daily) R.string.goal_summary_exact_count_daily else R.string.goal_summary_exact_count,
                target,
            )
        minimum != null && target != null && maximum != null ->
            stringResource(
                if (daily) R.string.goal_summary_bounded_count_daily else R.string.goal_summary_bounded_count,
                minimum,
                target,
                maximum,
            )
        minimum != null && target != null ->
            stringResource(
                if (daily) R.string.goal_summary_stretch_count_daily else R.string.goal_summary_stretch_count,
                minimum,
                target,
            )
        minimum != null -> stringResource(
            if (daily) R.string.goal_summary_minimum_count_daily else R.string.goal_summary_minimum_count,
            minimum,
        )
        target != null -> stringResource(
            if (daily) R.string.goal_summary_target_times_daily else R.string.goal_summary_target_times,
            target,
        )
        maximum != null -> stringResource(R.string.goal_details_maximum_count, maximum)
        else -> fallbackNoTarget
    }

@Composable
private fun capBehaviorSummary(behavior: CountCapBehavior): String =
    when (behavior) {
        CountCapBehavior.AllowOverTarget -> stringResource(R.string.goal_details_cap_allow)
        CountCapBehavior.WarnOverTarget -> stringResource(R.string.goal_details_cap_warn)
        CountCapBehavior.BlockAtTarget -> stringResource(R.string.goal_details_cap_block_target)
        CountCapBehavior.BlockAtMaximum -> stringResource(R.string.goal_details_cap_block_maximum)
    }

@Composable
private fun completionSummary(goal: Goal): String =
    if (goal.autoCompleteOnTarget) {
        stringResource(R.string.goal_details_completion_target)
    } else {
        stringResource(R.string.goal_details_completion_manual)
    }

@Composable
private fun durationSummary(goal: Goal): String =
    when {
        goal.durationDays != null -> stringResource(R.string.goal_summary_duration_days, goal.durationDays)
        goal.endDate != null -> stringResource(R.string.goal_details_duration_until, goal.endDate.toString())
        else -> stringResource(R.string.goal_summary_duration_ongoing)
    }

@Composable
private fun slotTitle(slot: GoalSlot): String =
    slot.label?.takeIf { it.isNotBlank() } ?: when (slot.slotType) {
        GoalSlotType.ANYTIME -> stringResource(R.string.slot_anytime)
        GoalSlotType.PRAYER -> {
            val relation = slot.prayerRelation?.localizedTitle().orEmpty()
            val prayer = slot.prayerName?.localizedName().orEmpty()
            listOf(relation, prayer).filter { it.isNotBlank() }.joinToString(" ")
        }
        GoalSlotType.TIME_WINDOW -> stringResource(R.string.goal_details_slot_number, slot.sortOrder + 1)
    }

private fun slotTimingSubtitle(slot: GoalSlot): String =
    when (slot.slotType) {
        GoalSlotType.ANYTIME -> ""
        GoalSlotType.PRAYER -> slot.timingValue.orEmpty().replace('_', ' ')
        GoalSlotType.TIME_WINDOW -> {
            val start = slot.startMinute ?: return ""
            val end = slot.endMinute ?: return ""
            "${start.toClockText()}-${end.toClockText()}"
        }
    }

@Composable
private fun reminderSummary(reminder: GoalReminder, goal: Goal): String =
    when (reminder.reminderType) {
        ReminderType.FIXED_TIME -> stringResource(
            R.string.goal_summary_reminders_time,
            "%02d:%02d".format(reminder.hour ?: 0, reminder.minute ?: 0),
        )
        ReminderType.PRAYER_OFFSET -> {
            val targetSlot = reminder.slotId?.let { slotId -> goal.activeSlots.firstOrNull { it.id == slotId } }
            if (targetSlot == null) {
                stringResource(R.string.goal_details_reminder_prayer_offset_all, reminder.offsetMinutes ?: 0)
            } else {
                stringResource(
                    R.string.goal_details_reminder_prayer_offset_slot,
                    slotTitle(targetSlot),
                    reminder.offsetMinutes ?: 0,
                )
            }
        }
        ReminderType.TIME_WINDOW_START -> {
            val targetSlot = reminder.slotId?.let { slotId -> goal.activeSlots.firstOrNull { it.id == slotId } }
            if (targetSlot == null) {
                stringResource(R.string.goal_details_reminder_window_start_all)
            } else {
                stringResource(R.string.goal_details_reminder_window_start_slot, slotTitle(targetSlot))
            }
        }
    }

private fun CalendarSystem.displayName(): String =
    name.lowercase().replaceFirstChar { it.uppercase() }

private fun DayOfWeek.shortName(): String =
    name.take(3).lowercase().replaceFirstChar { it.uppercase() }

private fun Int.toClockText(): String {
    val clamped = coerceIn(0, 24 * 60)
    val hour24 = (clamped / 60) % 24
    val minute = clamped % 60
    val suffix = if (hour24 < 12) "AM" else "PM"
    val hour12 = when (val normalized = hour24 % 12) {
        0 -> 12
        else -> normalized
    }
    return "%d:%02d %s".format(hour12, minute, suffix)
}

@Preview(showBackground = true)
@Composable
private fun GoalDetailPreview() {
    AwradDhikrGoalsTrackerTheme {
        GoalDetailContent(
            uiState = GoalDetailUiState(
                isLoading = false,
                goal = Goal(
                    id = java.util.UUID.randomUUID(),
                    dhikrId = java.util.UUID.randomUUID(),
                    targetPolicy = TargetPolicy.PER_DUE_DATE,
                    slots = listOf(
                        GoalSlot(
                            id = java.util.UUID.randomUUID(),
                            goalId = java.util.UUID.randomUUID(),
                            slotType = GoalSlotType.ANYTIME,
                            targetCount = 100,
                        )
                    ),
                    startDate = LocalDate.parse("2026-05-27"),
                ),
                dhikr = Dhikr(
                    id = java.util.UUID.randomUUID(),
                    title = "Istighfar",
                    arabic = "أستغفر الله",
                    transliteration = "Astaghfirullah",
                    translation = "I seek forgiveness from Allah",
                    audioUrl = null,
                    audioFileName = null,
                    category = DhikrCategory.FORGIVENESS,
                ),
                progress = GoalProgressSummary(
                    progressCount = 22,
                    targetCount = 100,
                    progress = 0.22f,
                    remainingCount = 78,
                    targetDisplay = "100",
                ),
                effectiveToday = LocalDate.parse("2026-05-27"),
            ),
            onNavigateBack = {},
            onNavigateToCounting = {},
            onNavigateToEdit = {},
            onNavigateToEditSchedule = {},
            onNavigateToEditReminders = {},
        )
    }
}
