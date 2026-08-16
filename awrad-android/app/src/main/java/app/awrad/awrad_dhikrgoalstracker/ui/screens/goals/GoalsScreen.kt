package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import androidx.compose.foundation.background
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.draw.clip
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.outlined.Archive
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Unarchive
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.BottomSheetDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.pluralStringResource
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
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualSkeleton
import app.awrad.awrad_dhikrgoalstracker.ui.components.SectionHeader
import app.awrad.awrad_dhikrgoalstracker.ui.components.StreakSection
import app.awrad.awrad_dhikrgoalstracker.ui.components.compactGoalCount
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goaldetail.DetailsDisclosure
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goaldetail.SessionsSection
import app.awrad.awrad_dhikrgoalstracker.ui.sync.ProgressSyncRefreshViewModel
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme
import app.awrad.awrad_dhikrgoalstracker.util.GoalProgressCalculator
import app.awrad.awrad_dhikrgoalstracker.util.StreakInfo
import java.time.LocalDate
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
    onNavigateToEdit: (AwradId) -> Unit,
    onNavigateToEditSchedule: (AwradId) -> Unit,
    onNavigateToEditReminders: (AwradId) -> Unit,
    viewModel: GoalsViewModel = hiltViewModel(),
    refreshViewModel: ProgressSyncRefreshViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val isRefreshing by refreshViewModel.isRefreshing.collectAsStateWithLifecycle()
    val density = LocalDensity.current
    val statusBarTopPadding = with(density) { WindowInsets.statusBars.getTop(this).toDp() }
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
    val pagerState = rememberPagerState(initialPage = 0) { 2 }
    val scope = rememberCoroutineScope()
    var tabCentersPx by remember { mutableStateOf(listOf<Float>()) }
    var sheetLeftPx by remember { mutableStateOf(0f) }
    var selectedGoal by remember { mutableStateOf<GoalDisplayItem?>(null) }
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
                        IconButton(
                            onClick = onNavigateToCreateGoal,
                            modifier = Modifier
                                .size(40.dp)
                                .clip(CircleShape)
                                .background(MaterialTheme.colorScheme.primaryContainer),
                        ) {
                            Icon(
                                imageVector = Icons.Filled.Add,
                                contentDescription = stringResource(R.string.cd_create_goal),
                                tint = MaterialTheme.colorScheme.onPrimaryContainer,
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
                                    0 -> ActiveGoalsPane(
                                        uiState = uiState,
                                        onNavigateToCounting = onNavigateToCounting,
                                        onShowDetails = { selectedGoal = it },
                                    )

                                    else -> HistoryGoalsPane(
                                        uiState = uiState,
                                        onNavigateToGoalDetail = onNavigateToGoalDetail,
                                        onShowDetails = { selectedGoal = it },
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

    selectedGoal?.let { item ->
        GoalDetailsBottomSheet(
            goal = item.goal,
            dhikrName = item.dhikrName,
            todayCount = item.todayCount,
            streakDays = item.streakDays,
            streakInfo = item.streakInfo,
            effectiveToday = item.effectiveToday,
            slotCountsToday = item.slotCountsToday,
            slotCountsAllTime = item.slotCountsAllTime,
            onDismiss = { selectedGoal = null },
            onArchive = {
                selectedGoal = null
                viewModel.archiveGoal(item.goal)
            },
            onRestore = {
                selectedGoal = null
                viewModel.restoreGoal(item.goal)
            },
            onDelete = {
                selectedGoal = null
                viewModel.deleteGoal(item.goal.id)
            },
            onEditCounting = { onNavigateToEdit(item.goal.id) },
            onEditSchedule = { onNavigateToEditSchedule(item.goal.id) },
            onEditReminders = { onNavigateToEditReminders(item.goal.id) },
        )
    }
}

@Composable
private fun ActiveGoalsPane(
    uiState: GoalsUiState,
    onNavigateToCounting: (AwradId) -> Unit,
    onShowDetails: (GoalDisplayItem) -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(top = 12.dp, bottom = 112.dp),
    ) {
        when (activeGoalsPaneContent(uiState)) {
            GoalsPaneContentState.Loading -> {
                items(3) { GoalListSkeletonItem() }
            }
            GoalsPaneContentState.Content -> {
                activeGoalsContent(
                    uiState = uiState,
                    onNavigateToCounting = onNavigateToCounting,
                    onShowDetails = onShowDetails,
                )
            }
            GoalsPaneContentState.Empty -> {
                item {
                    RitualEmptyState(
                        title = stringResource(R.string.goals_active_empty_title),
                        body = stringResource(R.string.goals_active_empty_hint),
                        icon = Icons.Filled.Add,
                        modifier = Modifier.padding(horizontal = 20.dp, vertical = 28.dp),
                    )
                }
            }
        }

        item { Spacer(modifier = Modifier.height(16.dp)) }
    }
}

private fun androidx.compose.foundation.lazy.LazyListScope.activeGoalsContent(
    uiState: GoalsUiState,
    onNavigateToCounting: (AwradId) -> Unit,
    onShowDetails: (GoalDisplayItem) -> Unit,
) {
    if (uiState.todayGoals.isNotEmpty()) {
        item {
            SectionHeader(title = stringResource(R.string.goals_section_today))
        }
        items(uiState.todayGoals) { item ->
            GoalListItem(
                item = item,
                onClick = { onNavigateToCounting(item.goal.id) },
                onShowDetails = { onShowDetails(item) },
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
                onShowDetails = { onShowDetails(item) },
            )
        }
    }
}

@Composable
private fun HistoryGoalsPane(
    uiState: GoalsUiState,
    onNavigateToGoalDetail: (AwradId) -> Unit,
    onShowDetails: (GoalDisplayItem) -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(top = 12.dp, bottom = 112.dp),
    ) {
        when (historyGoalsPaneContent(uiState)) {
            GoalsPaneContentState.Loading -> {
                items(3) { GoalListSkeletonItem() }
            }
            GoalsPaneContentState.Content -> historyGoalsContent(
                uiState = uiState,
                onNavigateToGoalDetail = onNavigateToGoalDetail,
                onShowDetails = onShowDetails,
            )
            GoalsPaneContentState.Empty -> {
                item {
                    RitualEmptyState(
                        title = stringResource(R.string.goals_history_empty_title),
                        body = stringResource(R.string.goals_history_empty_hint),
                        icon = Icons.Outlined.Archive,
                        modifier = Modifier.padding(horizontal = 20.dp, vertical = 28.dp),
                    )
                }
            }
        }

        item { Spacer(modifier = Modifier.height(16.dp)) }
    }
}

private fun androidx.compose.foundation.lazy.LazyListScope.historyGoalsContent(
    uiState: GoalsUiState,
    onNavigateToGoalDetail: (AwradId) -> Unit,
    onShowDetails: (GoalDisplayItem) -> Unit,
) {
    if (uiState.pastGoals.isNotEmpty()) {
        item {
            SectionHeader(title = stringResource(R.string.goals_section_past))
        }
        items(uiState.pastGoals) { item ->
            GoalListItem(
                item = item,
                onClick = { onNavigateToGoalDetail(item.goal.id) },
                onShowDetails = { onShowDetails(item) },
            )
        }
    }

    if (uiState.completedGoals.isNotEmpty()) {
        item {
            SectionHeader(title = stringResource(R.string.goals_section_completed))
        }
        items(uiState.completedGoals) { item ->
            GoalListItem(
                item = item,
                onClick = { onNavigateToGoalDetail(item.goal.id) },
                onShowDetails = { onShowDetails(item) },
            )
        }
    }

    if (uiState.archivedGoals.isNotEmpty()) {
        item {
            SectionHeader(title = stringResource(R.string.goals_section_archived))
        }
        items(uiState.archivedGoals) { item ->
            GoalListItem(
                item = item,
                onClick = { onNavigateToGoalDetail(item.goal.id) },
                onShowDetails = { onShowDetails(item) },
            )
        }
    }
}

@Composable
private fun GoalListSkeletonItem() {
    RitualCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 4.dp),
        shape = RoundedCornerShape(22.dp),
        containerColor = if (isAwradDarkTheme()) {
            MaterialTheme.colorScheme.surfaceContainer
        } else {
            MaterialTheme.colorScheme.surface
        },
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            RitualSkeleton(modifier = Modifier.size(48.dp), shape = CircleShape)
            Spacer(modifier = Modifier.width(14.dp))
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                RitualSkeleton(modifier = Modifier.width(160.dp).height(19.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    RitualSkeleton(modifier = Modifier.width(74.dp).height(22.dp), shape = RoundedCornerShape(20.dp))
                    RitualSkeleton(modifier = Modifier.width(62.dp).height(22.dp), shape = RoundedCornerShape(20.dp))
                }
            }
            Spacer(modifier = Modifier.width(8.dp))
            RitualSkeleton(modifier = Modifier.size(28.dp), shape = CircleShape)
        }
    }
}

@Composable
private fun GoalListItem(
    item: GoalDisplayItem,
    onClick: () -> Unit,
    onShowDetails: () -> Unit,
) {
    val displayCount = item.todayCount
    val displayCountLabel = remember(displayCount) { compactGoalCount(displayCount) }

    RitualCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 4.dp),
        onClick = onClick,
        shape = RoundedCornerShape(22.dp),
        containerColor = if (isAwradDarkTheme()) {
            MaterialTheme.colorScheme.surfaceContainer
        } else {
            MaterialTheme.colorScheme.surface
        },
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

            IconButton(
                onClick = { onShowDetails() },
                modifier = Modifier.size(36.dp),
            ) {
                Icon(
                    imageVector = Icons.Filled.MoreVert,
                    contentDescription = stringResource(R.string.goal_details_more_options),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(20.dp),
                )
            }
        }
    }
}

/** Extra per-screen actions (e.g. estimates, adjust count) surfaced inside the details sheet. */
internal data class GoalSheetAction(
    val label: String,
    val icon: ImageVector,
    val onClick: () -> Unit,
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun GoalDetailsBottomSheet(
    goal: Goal,
    dhikrName: String,
    todayCount: Long,
    streakDays: Int,
    streakInfo: StreakInfo?,
    effectiveToday: LocalDate,
    slotCountsToday: Map<AwradId, Long>,
    slotCountsAllTime: Map<AwradId, Long>,
    onDismiss: () -> Unit,
    onArchive: () -> Unit,
    onRestore: () -> Unit,
    onDelete: () -> Unit,
    onEditCounting: () -> Unit,
    onEditSchedule: () -> Unit,
    onEditReminders: () -> Unit,
    extraActions: List<GoalSheetAction> = emptyList(),
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var showDeleteConfirmation by remember { mutableStateOf(false) }
    val goalName = dhikrName.ifBlank { stringResource(R.string.goal_details_goal_fallback) }
    val statement = stringResource(R.string.goal_sheet_statement, goalName, goalTag(goal))

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        modifier = Modifier.statusBarsPadding(),
        sheetState = sheetState,
        dragHandle = { BottomSheetDefaults.DragHandle() },
        containerColor = MaterialTheme.colorScheme.surface,
    ) {
        Column(
            modifier = Modifier
                .fillMaxHeight()
                .statusBarsPadding()
                .navigationBarsPadding(),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 20.dp, end = 8.dp, top = 14.dp, bottom = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = stringResource(R.string.goal_details_title),
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Text(
                        text = goalName,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                IconButton(onClick = onDismiss) {
                    Icon(
                        imageVector = Icons.Filled.Close,
                        contentDescription = stringResource(R.string.goal_sheet_close),
                    )
                }
            }

            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.55f))

            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp, vertical = 24.dp),
                verticalArrangement = Arrangement.spacedBy(24.dp),
            ) {
                Surface(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(20.dp),
                    color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.55f),
                ) {
                    Text(
                        text = statement,
                        modifier = Modifier.padding(horizontal = 18.dp, vertical = 20.dp),
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                    )
                }

                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(
                        text = stringResource(R.string.goal_sheet_quick_stats),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        GoalQuickStat(
                            label = stringResource(R.string.goal_sheet_today),
                            value = compactGoalCount(todayCount),
                            modifier = Modifier.weight(1f),
                        )
                        GoalQuickStat(
                            label = stringResource(R.string.goal_sheet_current_streak),
                            value = pluralStringResource(
                                R.plurals.goal_sheet_days,
                                streakDays,
                                streakDays,
                            ),
                            modifier = Modifier.weight(1f),
                        )
                        GoalQuickStat(
                            label = stringResource(R.string.goal_sheet_all_time),
                            value = compactGoalCount(goal.totalCompletedCount),
                            modifier = Modifier.weight(1f),
                        )
                    }
                }

                // History & streak card — same as the counting page's history bottom sheet.
                Surface(
                    shape = RoundedCornerShape(16.dp),
                    color = MaterialTheme.colorScheme.surfaceContainerLow,
                    tonalElevation = 1.dp,
                ) {
                    StreakSection(
                        currentStreak = streakInfo?.currentStreak ?: streakDays,
                        activeDates = streakInfo?.activeDates.orEmpty(),
                        today = effectiveToday,
                        earliestDate = goal.startDate,
                        streakInfo = streakInfo,
                        modifier = Modifier.padding(14.dp),
                    )
                }

                // Sessions + details — merged from the redesigned detail screen.
                SessionsSection(
                    goal = goal,
                    slotCountsToday = slotCountsToday,
                    slotCountsAllTime = slotCountsAllTime,
                    onEdit = { onEditSchedule() },
                )

                DetailsDisclosure(
                    goal = goal,
                    onEditCounting = onEditCounting,
                    onEditSchedule = onEditSchedule,
                    onEditReminders = onEditReminders,
                )

                if (extraActions.isNotEmpty()) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        extraActions.forEach { action ->
                            OutlinedButton(
                                onClick = action.onClick,
                                modifier = Modifier
                                    .weight(1f)
                                    .height(48.dp),
                                shape = RoundedCornerShape(14.dp),
                            ) {
                                Icon(action.icon, contentDescription = null)
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(action.label)
                            }
                        }
                    }
                }
            }

            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.55f))
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                OutlinedButton(
                    onClick = if (goal.isPaused) onRestore else onArchive,
                    enabled = goal.isPaused || (goal.isActive && !goal.isCompleted),
                    modifier = Modifier
                        .weight(1f)
                        .height(52.dp),
                    shape = RoundedCornerShape(16.dp),
                ) {
                    Icon(
                        imageVector = if (goal.isPaused) {
                            Icons.Outlined.Unarchive
                        } else {
                            Icons.Outlined.Archive
                        },
                        contentDescription = null,
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        stringResource(
                            if (goal.isPaused) R.string.action_restore else R.string.action_archive,
                        ),
                    )
                }
                Button(
                    onClick = { showDeleteConfirmation = true },
                    modifier = Modifier
                        .weight(1f)
                        .height(52.dp),
                    shape = RoundedCornerShape(16.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.error,
                        contentColor = MaterialTheme.colorScheme.onError,
                    ),
                ) {
                    Icon(Icons.Outlined.Delete, contentDescription = null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(stringResource(R.string.action_delete))
                }
            }
        }
    }

    if (showDeleteConfirmation) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirmation = false },
            title = { Text(stringResource(R.string.goal_sheet_delete_title)) },
            text = { Text(stringResource(R.string.goal_sheet_delete_message)) },
            confirmButton = {
                TextButton(
                    onClick = {
                        showDeleteConfirmation = false
                        onDelete()
                    },
                ) {
                    Text(
                        text = stringResource(R.string.action_delete),
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirmation = false }) {
                    Text(stringResource(R.string.action_cancel))
                }
            },
        )
    }
}

@Composable
private fun GoalQuickStat(
    label: String,
    value: String,
    modifier: Modifier = Modifier,
) {
    Surface(
        modifier = modifier.height(96.dp),
        shape = RoundedCornerShape(18.dp),
        color = MaterialTheme.colorScheme.surfaceContainer,
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 14.dp),
            verticalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = value,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = label,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
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
internal fun goalScheduleTag(goal: Goal): String? = when (goal.recurrence.frequency) {
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
