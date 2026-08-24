package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalPreset
import app.awrad.awrad_dhikrgoalstracker.service.PreviewPlaybackState
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalValidationResult
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.TargetDraft

/**
 * Compatibility entry point for callers that still refer to the quick pane.
 * The post-dhikr screen intentionally uses the established simple-goal layout.
 */
@Composable
fun QuickCreatePane(
    dhikr: Dhikr,
    audioState: PreviewPlaybackState,
    draft: GoalDraft,
    validation: GoalValidationResult,
    isCreating: Boolean,
    onTogglePlayback: () -> Unit,
    onSelectQuickPreset: (GoalPreset) -> Unit,
    onDraftChange: (GoalDraft) -> Unit,
    onTargetChange: (TargetDraft) -> Unit,
    onCreate: () -> Unit,
    onAdvanced: () -> Unit,
    onShowFullQuran: (AwradId) -> Unit = {},
    onChangeDhikr: () -> Unit = {},
    canChangeDhikr: Boolean = false,
    modifier: Modifier = Modifier,
) {
    SimpleTargetPane(
        dhikr = dhikr,
        audioState = audioState,
        draft = draft,
        validation = validation,
        isCreating = isCreating,
        canChangeDhikr = canChangeDhikr,
        onTogglePlayback = onTogglePlayback,
        onShowFullQuran = onShowFullQuran,
        onChangeDhikr = onChangeDhikr,
        onTargetChange = onTargetChange,
        onCreate = onCreate,
        onSelectQuickPreset = onSelectQuickPreset,
        onDraftChange = onDraftChange,
        onAdvanced = onAdvanced,
        showTypeSelector = true,
        modifier = modifier,
    )
}
