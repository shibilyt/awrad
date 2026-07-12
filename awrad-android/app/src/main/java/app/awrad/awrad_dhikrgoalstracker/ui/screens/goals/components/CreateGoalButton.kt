package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualPrimaryButton

@Composable
fun CreateGoalButton(
    onClick: () -> Unit,
    isLoading: Boolean,
    enabled: Boolean,
    modifier: Modifier = Modifier,
    labelRes: Int = R.string.create_goal,
) {
    RitualPrimaryButton(
        text = stringResource(labelRes),
        onClick = onClick,
        modifier = modifier,
        enabled = enabled && !isLoading,
        isLoading = isLoading,
    )
}
