package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.outlined.Archive
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import app.awrad.awrad_dhikrgoalstracker.ui.components.DayProgressRing
import app.awrad.awrad_dhikrgoalstracker.ui.components.GoalStreakChip
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualCard
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualEmptyState
import app.awrad.awrad_dhikrgoalstracker.ui.components.SectionHeader
import app.awrad.awrad_dhikrgoalstracker.util.GoalProgressCalculator

@Composable
fun GoalsScreen(
    onNavigateToCounting: (AwradId) -> Unit,
    onNavigateToGoalDetail: (AwradId) -> Unit,
    onNavigateToCreateGoal: () -> Unit,
    viewModel: GoalsViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val density = LocalDensity.current
    val statusBarTopPadding = with(density) { WindowInsets.statusBars.getTop(this).toDp() }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(top = statusBarTopPadding, bottom = 112.dp),
    ) {
        item {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp)
                    .padding(top = 16.dp, bottom = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = stringResource(R.string.goals_title),
                    style = MaterialTheme.typography.headlineMedium,
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
        }

        if (uiState.activeGoals.isNotEmpty()) {
            item {
                SectionHeader(title = stringResource(R.string.goals_section_active))
            }
            items(uiState.activeGoals) { item ->
                GoalListItem(
                    item = item,
                    onClick = { onNavigateToCounting(item.goal.id) },
                    onDelete = { viewModel.deleteGoal(item.goal.id) },
                )
            }
        }

        if (uiState.completedGoals.isNotEmpty()) {
            item {
                Spacer(modifier = Modifier.height(16.dp))
                SectionHeader(title = stringResource(R.string.goals_section_completed))
            }
            items(uiState.completedGoals) { item ->
                GoalListItem(
                    item = item,
                    onClick = { onNavigateToGoalDetail(item.goal.id) },
                    onDelete = { viewModel.deleteGoal(item.goal.id) },
                )
            }
        }

        if (uiState.activeGoals.isEmpty() && uiState.completedGoals.isEmpty() && !uiState.isLoading) {
            item {
                RitualEmptyState(
                    title = stringResource(R.string.goals_empty_title),
                    body = stringResource(R.string.goals_empty_hint),
                    icon = Icons.Filled.Add,
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

    RitualCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 4.dp),
        onClick = onClick,
        shape = RoundedCornerShape(22.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (item.dailyTarget > 0) {
                DayProgressRing(
                    progress = item.overallProgress,
                    count = item.todayCount,
                    ringColor = MaterialTheme.colorScheme.secondary,
                    trackColor = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.62f),
                    textColor = MaterialTheme.colorScheme.onSurface,
                    size = 48.dp,
                    strokeWidth = 4.dp,
                )
            } else {
                Text(
                    text = "$displayCount",
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
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
private fun goalTag(goal: Goal): String {
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
    return when {
        goal.capBehavior == CountCapBehavior.BlockAtMaximum &&
            minimum != null && maximum != null && minimum < target && target < maximum ->
            stringResource(R.string.goal_summary_bounded_count, minimum, target, maximum)
        goal.capBehavior == CountCapBehavior.BlockAtMaximum && maximum == target ->
            stringResource(R.string.goal_summary_exact_count, target)
        minimum != null && minimum < target ->
            stringResource(R.string.goal_summary_stretch_count, minimum, target)
        minimum != null && minimum == target ->
            stringResource(R.string.goal_summary_minimum_count, minimum)
        goal.targetPolicy == TargetPolicy.CUMULATIVE_TOTAL ->
            stringResource(R.string.goal_summary_target_total, target)
        goal.targetPolicy == TargetPolicy.PERIOD_TOTAL ->
            stringResource(R.string.goal_summary_target_period, target)
        else -> stringResource(R.string.goal_summary_target_times, target)
    }
}
