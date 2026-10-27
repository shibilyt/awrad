package app.awrad.core.designsystem.component

import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import app.awrad.core.designsystem.theme.AwradStates

/**
 * A disabled control keeps its colours and is drawn whole at `states.disabled.opacity` (0.38): there are no
 * disabled colours. Components pass their enabled colours as Material's disabled ones and add this.
 */
internal fun Modifier.disabledOpacity(enabled: Boolean): Modifier =
    if (enabled) this else alpha(AwradStates.disabledOpacity)
