package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AllInclusive
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.foundation.BorderStroke
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalPreset
import app.awrad.awrad_dhikrgoalstracker.service.PreviewPlaybackState
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualCard
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualIconTile
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualMetricChip
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualPrimaryButton
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.CountInputField
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.DhikrHeaderCard
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalValidationResult
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.TargetDraft
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme

/**
 * Screen 2 of the simple create-goal flow. Shows the live goal sentence, the
 * chosen dhikr (tappable to change), and — for Every day / One time — a single
 * target stepper. No target renders a tracker note with nothing to enter. The
 * whole form is one number.
 */
@Composable
fun SimpleTargetPane(
    dhikr: Dhikr?,
    audioState: PreviewPlaybackState,
    draft: GoalDraft,
    validation: GoalValidationResult,
    isCreating: Boolean,
    canChangeDhikr: Boolean,
    onTogglePlayback: () -> Unit,
    onChangeDhikr: () -> Unit,
    onTargetChange: (TargetDraft) -> Unit,
    onCreate: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val dhikrName = dhikr?.let { it.transliteration.ifBlank { it.title } }
        ?: stringResource(R.string.simple_target_dhikr_placeholder)

    Box(modifier = modifier.fillMaxSize()) {
        Column(modifier = Modifier.fillMaxSize()) {
            SimpleGoalHero(sentence = goalSentence(dhikrName, draft))

            Column(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp)
                    .padding(top = 8.dp, bottom = 108.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                if (dhikr != null) {
                    Column {
                        DhikrHeaderCard(
                            dhikr = dhikr,
                            audioState = audioState,
                            onTogglePlayback = onTogglePlayback,
                            collapsed = true,
                        )
                        if (canChangeDhikr) {
                            TextButton(
                                onClick = onChangeDhikr,
                                modifier = Modifier.align(Alignment.End),
                            ) {
                                Text(
                                    text = stringResource(R.string.composer_change_dhikr),
                                    style = MaterialTheme.typography.labelLarge,
                                    color = MaterialTheme.colorScheme.primary,
                                )
                            }
                        }
                    }
                } else {
                    ChooseDhikrCard(onClick = onChangeDhikr)
                }

                when (draft.preset) {
                    GoalPreset.TRACKER -> SimpleTrackerNote()
                    GoalPreset.ONE_TIME -> SimpleCountField(
                        draft = draft,
                        labelRes = R.string.simple_target_onetime_label,
                        quickValues = listOf(1000, 10000, 70000),
                        onTargetChange = onTargetChange,
                    )
                    else -> SimpleCountField(
                        draft = draft,
                        labelRes = R.string.simple_target_daily_label,
                        quickValues = listOf(33, 100, 313),
                        onTargetChange = onTargetChange,
                    )
                }
            }
        }

        SimpleCreateBar(
            validation = validation,
            isCreating = isCreating,
            onCreate = onCreate,
            modifier = Modifier.align(Alignment.BottomCenter),
        )
    }
}

@Composable
private fun SimpleCountField(
    draft: GoalDraft,
    labelRes: Int,
    quickValues: List<Int>,
    onTargetChange: (TargetDraft) -> Unit,
) {
    val count = (draft.targetDraft as? TargetDraft.Fixed)?.count ?: ""
    CountInputField(
        value = count,
        onValueChange = { onTargetChange(TargetDraft.Fixed(it)) },
        label = stringResource(labelRes),
        quickValues = quickValues,
    )
}

@Composable
private fun SimpleGoalHero(sentence: String) {
    val accent = MaterialTheme.colorScheme.primary
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 8.dp),
        shape = RoundedCornerShape(22.dp),
        color = accent.copy(alpha = if (isAwradDarkTheme()) 0.16f else 0.12f),
    ) {
        Row(modifier = Modifier.padding(horizontal = 20.dp, vertical = 18.dp)) {
            Box(
                modifier = Modifier
                    .width(4.dp)
                    .height(54.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(accent),
            )
            Spacer(modifier = Modifier.width(16.dp))
            Column {
                Text(
                    text = stringResource(R.string.composer_your_goal).uppercase(),
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = accent,
                    letterSpacing = 1.5.sp,
                )
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = sentence,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
            }
        }
    }
}

@Composable
private fun ChooseDhikrCard(onClick: () -> Unit) {
    RitualCard(modifier = Modifier.fillMaxWidth(), onClick = onClick) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 14.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            RitualIconTile(icon = Icons.Outlined.AllInclusive)
            Text(
                text = stringResource(R.string.create_goal_choose_dhikr_title),
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.weight(1f),
            )
            RitualMetricChip(text = stringResource(R.string.action_choose))
        }
    }
}

@Composable
private fun SimpleTrackerNote() {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(20.dp),
        color = MaterialTheme.colorScheme.surfaceContainerLow,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.28f)),
    ) {
        Row(
            modifier = Modifier.padding(18.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.6f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Outlined.AllInclusive,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onPrimaryContainer,
                    modifier = Modifier.size(22.dp),
                )
            }
            Text(
                text = stringResource(R.string.composer_tracker_note),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun SimpleCreateBar(
    validation: GoalValidationResult,
    isCreating: Boolean,
    onCreate: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val error = validation.errors.values.firstOrNull()
    Surface(
        modifier = modifier.fillMaxWidth(),
        color = MaterialTheme.colorScheme.surface,
        shadowElevation = 12.dp,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(horizontal = 20.dp, vertical = 14.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            if (error != null) {
                Text(
                    text = error.localizedText(),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.error,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            RitualPrimaryButton(
                text = stringResource(R.string.action_create_goal),
                onClick = onCreate,
                enabled = validation.isValid,
                isLoading = isCreating,
            )
        }
    }
}
