package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

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
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.outlined.Archive
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
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
import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.RecurrenceFrequency
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import app.awrad.awrad_dhikrgoalstracker.ui.components.AwradPagerTabs
import app.awrad.awrad_dhikrgoalstracker.ui.components.DayProgressRing
import app.awrad.awrad_dhikrgoalstracker.ui.components.GoalStreakChip
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualCard
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualEmptyState
import app.awrad.awrad_dhikrgoalstracker.ui.components.SectionHeader
import app.awrad.awrad_dhikrgoalstracker.ui.components.compactGoalCount
import app.awrad.awrad_dhikrgoalstracker.ui.sync.ProgressSyncRefreshViewModel
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme
import app.awrad.awrad_dhikrgoalstracker.util.GoalProgressCalculator
import kotlinx.coroutines.launch
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.roundToInt

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GoalsScreen(
    onNavigateToCounting: (AwradId) -> Unit,
    onNavigateToGoalDetail: (AwradId) -> Unit,
    onNavigateToCreateGoal: () -> Unit,
    viewModel: GoalsViewModel = hiltViewModel(),
    refreshViewModel: ProgressSyncRefreshViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val isRefreshing by refreshViewModel.isRefreshing.collectAsStateWithLifecycle()
    val density = LocalDensity.current
    val statusBarTopPadding = with(density) { WindowInsets.statusBars.getTop(this).toDp() }
    val headerBackgroundColor = if (isAwradDarkTheme()) {
        Color.Transparent
    } else {
        MaterialTheme.colorScheme.surface
    }
    val pagerState = rememberPagerState(initialPage = 0) { 2 }
    val scope = rememberCoroutineScope()
    var tabCentersPx by remember { mutableStateOf(listOf<Float>()) }
    var sheetLeftPx by remember { mutableStateOf(0f) }
    val tabs = listOf(
        stringResource(R.string.goals_tab_active),
        stringResource(R.string.goals_tab_history),
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(headerBackgroundColor),
    ) {
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
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 20.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = stringResource(R.string.goals_title),
                            style = MaterialTheme.typography.displayMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface,
                            modifier = Modifier.weight(1f),
                        )
                        IconButton(onClick = onNavigateToCreateGoal) {
                            Icon(
                                imageVector = Icons.Filled.Add,
                                contentDescription = stringResource(R.string.cd_create_goal),
                                tint = MaterialTheme.colorScheme.onSurface,
                            )
                        }
                    }

                    AwradPagerTabs(
                        tabs = tabs,
                        pagerState = pagerState,
                        onTabSelected = { page ->
                            scope.launch { pagerState.animateScrollToPage(page) }
                        },
                        onTabCenters = { tabCentersPx = it },
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
                        color = MaterialTheme.colorScheme.surfaceContainer,
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
                                    0 -> ActiveGoalsPane(
                                        uiState = uiState,
                                        onNavigateToCounting = onNavigateToCounting,
                                        onDelete = viewModel::deleteGoal,
                                    )

                                    else -> HistoryGoalsPane(
                                        uiState = uiState,
                                        onNavigateToGoalDetail = onNavigateToGoalDetail,
                                        onDelete = viewModel::deleteGoal,
                                    )
                                }
                            }
                        }
                    }

                    if (tabCentersPx.isNotEmpty()) {
                        val indicatorPos = (pagerState.currentPage + pagerState.currentPageOffsetFraction)
                            .coerceIn(0f, (tabCentersPx.size - 1).toFloat())
                        val lowerIdx = floor(indicatorPos).toInt().coerceIn(0, tabCentersPx.lastIndex)
                        val upperIdx = ceil(indicatorPos).toInt().coerceIn(0, tabCentersPx.lastIndex)
                        val fraction = indicatorPos - lowerIdx
                        val nubWidth = 24.dp
                        val nubCenterX = lerp(tabCentersPx[lowerIdx], tabCentersPx[upperIdx], fraction) - sheetLeftPx
                        val nubHalfPx = with(density) { nubWidth.toPx() } / 2f
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
                }
            }
        }
    }
}

@Composable
private fun ActiveGoalsPane(
    uiState: GoalsUiState,
    onNavigateToCounting: (AwradId) -> Unit,
    onDelete: (AwradId) -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(top = 12.dp, bottom = 112.dp),
    ) {
        if (uiState.todayGoals.isNotEmpty()) {
            item {
                SectionHeader(title = stringResource(R.string.goals_section_today))
            }
            items(uiState.todayGoals) { item ->
                GoalListItem(
                    item = item,
                    onClick = { onNavigateToCounting(item.goal.id) },
                    onDelete = { onDelete(item.goal.id) },
                )
            }
        }

        if (uiState.upcomingGoals.isNotEmpty()) {
            item {
                if (uiState.todayGoals.isNotEmpty()) Spacer(modifier = Modifier.height(16.dp))
                SectionHeader(title = stringResource(R.string.goals_section_upcoming))
            }
            items(uiState.upcomingGoals) { item ->
                GoalListItem(
                    item = item,
                    onClick = { onNavigateToCounting(item.goal.id) },
                    onDelete = { onDelete(item.goal.id) },
                )
            }
        }

        if (
            uiState.todayGoals.isEmpty() &&
            uiState.upcomingGoals.isEmpty() &&
            !uiState.isLoading
        ) {
            item {
                RitualEmptyState(
                    title = stringResource(R.string.goals_active_empty_title),
                    body = stringResource(R.string.goals_active_empty_hint),
                    icon = Icons.Filled.Add,
                    modifier = Modifier.padding(horizontal = 20.dp, vertical = 28.dp),
                )
            }
        }

        item { Spacer(modifier = Modifier.height(16.dp)) }
    }
}

@Composable
private fun HistoryGoalsPane(
    uiState: GoalsUiState,
    onNavigateToGoalDetail: (AwradId) -> Unit,
    onDelete: (AwradId) -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(top = 12.dp, bottom = 112.dp),
    ) {
        if (uiState.historyGoals.isNotEmpty()) {
            item {
                SectionHeader(title = stringResource(R.string.goals_section_past))
            }
            items(uiState.historyGoals) { item ->
                GoalListItem(
                    item = item,
                    onClick = { onNavigateToGoalDetail(item.goal.id) },
                    onDelete = { onDelete(item.goal.id) },
                )
            }
        } else if (!uiState.isLoading) {
            item {
                RitualEmptyState(
                    title = stringResource(R.string.goals_history_empty_title),
                    body = stringResource(R.string.goals_history_empty_hint),
                    icon = Icons.Outlined.Archive,
                    modifier = Modifier.padding(horizontal = 20.dp, vertical = 28.dp),
                )
            }
        }

        item { Spacer(modifier = Modifier.height(16.dp)) }
    }
}

@Composable
private fun GoalListItem(
    item: GoalDisplayItem,
    onClick: () -> Unit,
    onDelete: () -> Unit,
) {
    var menuExpanded by remember { mutableStateOf(false) }

    val displayCount = item.todayCount
    val displayCountLabel = remember(displayCount) { compactGoalCount(displayCount) }

    RitualCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 4.dp),
        onClick = onClick,
        shape = RoundedCornerShape(22.dp),
        containerColor = MaterialTheme.colorScheme.surface,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (item.dailyTarget > 0 || item.goal.isCompleted) {
                val minimumTargetProgress = item.goal.minimumStreakCount
                    ?.takeIf { it > 0 && it < item.dailyTarget }
                    ?.toFloat()
                    ?.div(item.dailyTarget.toFloat())
                DayProgressRing(
                    progress = item.overallProgress,
                    count = item.todayCount,
                    ringColor = MaterialTheme.colorScheme.secondary,
                    trackColor = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.62f),
                    textColor = MaterialTheme.colorScheme.onSurface,
                    showCompletionIcon = !item.goal.isCompleted,
                    minimumTargetProgress = minimumTargetProgress,
                    minimumTargetColor = MaterialTheme.colorScheme.tertiary,
                    size = 48.dp,
                    strokeWidth = 4.dp,
                )
            } else {
                Box(
                    modifier = Modifier.size(48.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = displayCountLabel,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface,
                        maxLines = 1,
                    )
                }
            }

            Spacer(modifier = Modifier.width(14.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = item.dhikrName,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )

                Spacer(modifier = Modifier.height(6.dp))

                Row(verticalAlignment = Alignment.CenterVertically) {
                    Surface(
                        modifier = Modifier.weight(1f, fill = false),
                        shape = RoundedCornerShape(20.dp),
                        color = if (item.overallProgress >= 1f) {
                            MaterialTheme.colorScheme.secondaryContainer
                        } else {
                            MaterialTheme.colorScheme.primaryContainer
                        },
                    ) {
                        Text(
                            text = goalTag(item.goal),
                            style = MaterialTheme.typography.labelSmall,
                            color = if (item.overallProgress >= 1f) {
                                MaterialTheme.colorScheme.onSecondaryContainer
                            } else {
                                MaterialTheme.colorScheme.primary
                            },
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                    goalScheduleTag(item.goal)?.let { schedule ->
                        Spacer(modifier = Modifier.width(6.dp))
                        Surface(
                            modifier = Modifier.weight(1f, fill = false),
                            shape = RoundedCornerShape(20.dp),
                            color = MaterialTheme.colorScheme.surfaceVariant,
                        ) {
                            Text(
                                text = schedule,
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                    }
                    if (item.streakDays > 0) {
                        Spacer(modifier = Modifier.width(10.dp))
                        GoalStreakChip(streakDays = item.streakDays)
                    }
                }
            }

            Spacer(modifier = Modifier.width(8.dp))

            Box {
                IconButton(
                    onClick = { menuExpanded = true },
                    modifier = Modifier.size(36.dp),
                ) {
                    Icon(
                        imageVector = Icons.Filled.MoreVert,
                        contentDescription = "More options",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(20.dp),
                    )
                }
                DropdownMenu(
                    expanded = menuExpanded,
                    onDismissRequest = { menuExpanded = false },
                ) {
                    DropdownMenuItem(
                        text = { Text(stringResource(R.string.action_archive)) },
                        onClick = { menuExpanded = false },
                        leadingIcon = {
                            Icon(Icons.Outlined.Archive, contentDescription = null)
                        },
                    )
                    DropdownMenuItem(
                        text = {
                            Text(
                                stringResource(R.string.action_delete),
                                color = MaterialTheme.colorScheme.error,
                            )
                        },
                        onClick = {
                            menuExpanded = false
                            onDelete()
                        },
                        leadingIcon = {
                            Icon(
                                Icons.Outlined.Delete,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.error,
                            )
                        },
                    )
                }
            }
        }
    }
}

@Composable
internal fun goalTag(goal: Goal): String {
    if (goal.targetPolicy == TargetPolicy.NONE) {
        return stringResource(R.string.goal_summary_no_target)
    }

    if (goal.isPrayerBased) {
        val prayerSlots = goal.activeSlots.filter { it.slotType == GoalSlotType.PRAYER }
        val prayerTargets = prayerSlots.mapNotNull { it.targetCount }.distinct()
        val sharedTarget = prayerTargets.singleOrNull()
        return when {
            prayerSlots.size == 1 && sharedTarget != null ->
                stringResource(R.string.goal_summary_target_times, sharedTarget)
            sharedTarget != null ->
                stringResource(R.string.goal_summary_target_per_prayer_count, sharedTarget)
            else -> stringResource(R.string.goal_summary_target_per_prayer)
        }
    }

    val target = GoalProgressCalculator.getTargetCount(goal)
    val minimum = goal.minimumStreakCount
    val maximum = goal.maximumCount
    val isDaily = goal.recurrence.frequency == RecurrenceFrequency.DAILY
    return when {
        goal.capBehavior == CountCapBehavior.BlockAtMaximum &&
            minimum != null && maximum != null && minimum < target && target < maximum ->
            stringResource(
                if (isDaily) R.string.goal_summary_bounded_count_daily else R.string.goal_summary_bounded_count,
                minimum,
                target,
                maximum,
            )
        goal.capBehavior == CountCapBehavior.BlockAtMaximum && maximum == target ->
            stringResource(
                if (isDaily) R.string.goal_summary_exact_count_daily else R.string.goal_summary_exact_count,
                target,
            )
        minimum != null && minimum < target ->
            stringResource(
                if (isDaily) R.string.goal_summary_stretch_count_daily else R.string.goal_summary_stretch_count,
                minimum,
                target,
            )
        minimum != null && minimum == target ->
            stringResource(
                if (isDaily) R.string.goal_summary_minimum_count_daily else R.string.goal_summary_minimum_count,
                minimum,
            )
        goal.targetPolicy == TargetPolicy.CUMULATIVE_TOTAL ->
            stringResource(R.string.goal_summary_target_total, target)
        goal.targetPolicy == TargetPolicy.PERIOD_TOTAL ->
            stringResource(R.string.goal_summary_target_period, target)
        else -> stringResource(
            if (isDaily) R.string.goal_summary_target_times_daily else R.string.goal_summary_target_times,
            target,
        )
    }
}

@Composable
private fun goalScheduleTag(goal: Goal): String? = when (goal.recurrence.frequency) {
    RecurrenceFrequency.DAILY -> null
    RecurrenceFrequency.WEEKLY -> {
        val weekdays = goal.recurrence.weekdays
            .sortedBy { it.value }
            .joinToString(", ") { it.name.take(3).lowercase().replaceFirstChar { char -> char.uppercase() } }
        if (weekdays.isBlank()) stringResource(R.string.goal_summary_schedule_weekly)
        else stringResource(R.string.goal_summary_schedule_weekly_every, weekdays)
    }
    RecurrenceFrequency.MONTHLY -> stringResource(
        R.string.goal_summary_schedule_monthly,
        goal.recurrence.calendar.name.lowercase().replaceFirstChar { it.uppercase() },
    )
    RecurrenceFrequency.INTERVAL -> stringResource(
        R.string.goal_summary_schedule_interval,
        goal.recurrence.intervalDays ?: 1,
    )
    RecurrenceFrequency.YEARLY -> stringResource(R.string.goal_summary_schedule_yearly_short)
    RecurrenceFrequency.SEASON -> stringResource(R.string.goal_summary_schedule_season_short)
    RecurrenceFrequency.SPECIFIC_DATES -> stringResource(R.string.goal_summary_schedule_dates_short)
}
