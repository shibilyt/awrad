package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import androidx.annotation.StringRes
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalPreset
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualCard

/**
 * Screen 1 of the simple create-goal flow: choose the goal *shape*. Three real
 * shapes — Every day, One time, No target — plus a separate door into the
 * full-control Advanced composer. Text-only cards, no icons.
 */
@Composable
fun SelectGoalShapeStep(
    onSelectShape: (GoalPreset) -> Unit,
    onAdvanced: () -> Unit,
    modifier: Modifier = Modifier,
) {
    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 28.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Column(modifier = Modifier.padding(bottom = 4.dp)) {
                Text(
                    text = stringResource(R.string.create_goal_shape_title),
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = stringResource(R.string.create_goal_shape_subtitle),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
        }
        item {
            GoalShapeCard(
                titleRes = R.string.goal_shape_daily_title,
                descRes = R.string.goal_shape_daily_desc,
                onClick = { onSelectShape(GoalPreset.DAILY) },
            )
        }
        item {
            GoalShapeCard(
                titleRes = R.string.goal_shape_onetime_title,
                descRes = R.string.goal_shape_onetime_desc,
                onClick = { onSelectShape(GoalPreset.ONE_TIME) },
            )
        }
        item {
            GoalShapeCard(
                titleRes = R.string.goal_shape_notarget_title,
                descRes = R.string.goal_shape_notarget_desc,
                onClick = { onSelectShape(GoalPreset.TRACKER) },
            )
        }
        item { ShapeDivider(text = stringResource(R.string.goal_shape_or)) }
        item {
            GoalShapeCard(
                titleRes = R.string.goal_shape_advanced_title,
                descRes = R.string.goal_shape_advanced_desc,
                onClick = onAdvanced,
            )
        }
    }
}

@Composable
private fun GoalShapeCard(
    @StringRes titleRes: Int,
    @StringRes descRes: Int,
    onClick: () -> Unit,
) {
    RitualCard(modifier = Modifier.fillMaxWidth(), onClick = onClick) {
        Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 16.dp)) {
            Text(
                text = stringResource(titleRes),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = stringResource(descRes),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 3.dp),
            )
        }
    }
}

@Composable
private fun ShapeDivider(text: String) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        HorizontalDivider(modifier = Modifier.weight(1f))
        Text(
            text = text.uppercase(),
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            letterSpacing = 1.2.sp,
        )
        HorizontalDivider(modifier = Modifier.weight(1f))
    }
}
