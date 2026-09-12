package app.awrad.awrad_dhikrgoalstracker.ui.screens.onboarding

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.ui.theme.NotoNaskhArabicFontFamily

// ─── Goal Intro Scene (the hadith moment) ────────────────────────────────────

/**
 * A quiet, cinematic beat before the first goal: the Prophet's ﷺ own daily
 * practice of istighfar, revealed line by line.
 */
@Composable
internal fun GoalIntroScene() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 28.dp, vertical = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        AnimatedEntry(delayMillis = 0) {
            Text(
                text = stringResource(R.string.onboarding_goalintro_eyebrow),
                style = MaterialTheme.typography.labelLarge.copy(letterSpacing = 2.4.sp),
                fontWeight = FontWeight.SemiBold,
                color = greenAccent(),
                textAlign = TextAlign.Center,
            )
        }

        Spacer(modifier = Modifier.height(20.dp))

        AnimatedEntry(delayMillis = 350) {
            Text(
                text = stringResource(R.string.onboarding_goalintro_lead),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
                textAlign = TextAlign.Center,
            )
        }

        Spacer(modifier = Modifier.height(30.dp))

        AnimatedEntry(delayMillis = 1100) {
            HadithCard()
        }

        Spacer(modifier = Modifier.height(30.dp))

        AnimatedEntry(delayMillis = 2100) {
            Text(
                text = stringResource(R.string.onboarding_goalintro_close),
                style = MaterialTheme.typography.titleMedium,
                fontStyle = FontStyle.Italic,
                color = MaterialTheme.colorScheme.primary,
                textAlign = TextAlign.Center,
            )
        }
    }
}

@Composable
private fun HadithCard() {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(28.dp),
        color = MaterialTheme.colorScheme.surfaceContainerLow,
        border = BorderStroke(1.dp, greenAccent().copy(alpha = 0.35f)),
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 22.dp, vertical = 26.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = stringResource(R.string.onboarding_goalintro_hadith_arabic),
                fontFamily = NotoNaskhArabicFontFamily,
                fontSize = 24.sp,
                lineHeight = 46.sp,
                color = MaterialTheme.colorScheme.onSurface,
                textAlign = TextAlign.Center,
            )

            Spacer(modifier = Modifier.height(16.dp))

            OrnamentDivider()

            // Arabic locale blanks this — the hadith above is already Arabic.
            val translation = stringResource(R.string.onboarding_goalintro_hadith_translation)
            if (translation.isNotBlank()) {
                Spacer(modifier = Modifier.height(16.dp))

                Text(
                    text = translation,
                    style = MaterialTheme.typography.bodyLarge,
                    fontStyle = FontStyle.Italic,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
            }

            Spacer(modifier = Modifier.height(18.dp))

            HadithReferenceChip()
        }
    }
}

@Composable
internal fun HadithReferenceChip() {
    Surface(
        shape = RoundedCornerShape(14.dp),
        color = greenAccent().copy(alpha = 0.14f),
    ) {
        Text(
            text = stringResource(R.string.onboarding_goalintro_hadith_ref),
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
            color = greenAccent(),
        )
    }
}

// ─── First Goal Scene ────────────────────────────────────────────────────────

@Composable
internal fun FirstGoalScene(
    count: Int,
    onCountChanged: (Int) -> Unit,
) {
    val preset = FirstGoalPresets.starter
    OnboardingScene(
        // The starter card already carries the dhikr identity; keep this step
        // focused on the choice rather than repeating the brand mark.
        icon = {},
        title = stringResource(R.string.onboarding_goal_title),
        subtitle = stringResource(R.string.onboarding_goal_subtitle),
        topSpacerHeight = 0.dp,
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            AnimatedEntry(delayMillis = 120) {
                StarterDhikrCard(preset = preset)
            }

            AnimatedEntry(delayMillis = 240) {
                GoalCountPicker(
                    count = count,
                    preset = preset,
                    onCountChanged = onCountChanged,
                )
            }

            AnimatedEntry(delayMillis = 360) {
                GoalContextNote(
                    count = count,
                    recommendedCount = preset.defaultCount,
                )
            }
        }
    }
}

@Composable
private fun StarterDhikrCard(preset: FirstGoalPreset) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        color = MaterialTheme.colorScheme.surfaceContainerLow,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.55f)),
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 18.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = stringResource(R.string.onboarding_goal_starter_label),
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.fillMaxWidth(),
            )

            Spacer(modifier = Modifier.height(12.dp))

            Text(
                text = preset.arabic,
                modifier = Modifier.fillMaxWidth(),
                fontFamily = NotoNaskhArabicFontFamily,
                style = MaterialTheme.typography.headlineSmall,
                lineHeight = 42.sp,
                color = MaterialTheme.colorScheme.onSurface,
                textAlign = TextAlign.Center,
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = stringResource(preset.nameRes),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
                textAlign = TextAlign.Center,
            )
            Text(
                text = stringResource(preset.meaningRes),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }
    }
}

@Composable
private fun GoalCountPicker(
    count: Int,
    preset: FirstGoalPreset,
    onCountChanged: (Int) -> Unit,
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("onboarding-goal-count-picker"),
        shape = RoundedCornerShape(28.dp),
        color = greenContainerColor().copy(alpha = 0.46f),
        border = BorderStroke(1.dp, greenAccent().copy(alpha = 0.28f)),
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 18.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = stringResource(R.string.onboarding_goal_count_label),
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Text(
                        text = stringResource(R.string.onboarding_goal_choose_pace),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                if (count == preset.defaultCount) {
                    Text(
                        text = stringResource(R.string.onboarding_goal_recommended),
                        modifier = Modifier.testTag("onboarding-goal-recommended"),
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = greenAccent(),
                    )
                }
            }

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(164.dp),
            ) {
                Surface(
                    modifier = Modifier
                        .size(148.dp)
                        .align(Alignment.Center),
                    shape = CircleShape,
                    color = MaterialTheme.colorScheme.surface,
                    border = BorderStroke(1.dp, greenAccent().copy(alpha = 0.24f)),
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center,
                    ) {
                        Text(
                            text = count.toString(),
                            style = MaterialTheme.typography.displaySmall,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                        Text(
                            text = stringResource(R.string.onboarding_goal_count_unit),
                            style = MaterialTheme.typography.labelLarge,
                            fontWeight = FontWeight.SemiBold,
                            color = greenAccent(),
                        )
                    }
                }

                StepperButton(
                    icon = Icons.Filled.Remove,
                    contentDescription = stringResource(R.string.onboarding_goal_decrease),
                    enabled = count > FirstGoalPresets.MIN_COUNT,
                    modifier = Modifier
                        .align(Alignment.CenterStart)
                        .padding(start = 2.dp),
                    onClick = { onCountChanged(count - 1) },
                )
                StepperButton(
                    icon = Icons.Filled.Add,
                    contentDescription = stringResource(R.string.onboarding_goal_increase),
                    enabled = count < FirstGoalPresets.MAX_COUNT,
                    modifier = Modifier
                        .align(Alignment.CenterEnd)
                        .padding(end = 2.dp),
                    onClick = { onCountChanged(count + 1) },
                )
            }

            Text(
                text = stringResource(R.string.onboarding_goal_quick_hint),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(modifier = Modifier.height(10.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                FirstGoalPresets.quickCounts.forEach { value ->
                    val active = value == count
                    Surface(
                        onClick = { onCountChanged(value) },
                        modifier = Modifier
                            .weight(1f)
                            .height(54.dp)
                            .testTag("onboarding-goal-preset-$value"),
                        shape = RoundedCornerShape(16.dp),
                        color = if (active) greenAccent() else MaterialTheme.colorScheme.surface.copy(alpha = 0.78f),
                        border = if (active) null else BorderStroke(
                            1.dp,
                            MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.55f),
                        ),
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Text(
                                text = value.toString(),
                                style = MaterialTheme.typography.titleSmall,
                                fontWeight = FontWeight.SemiBold,
                                color = if (active) {
                                    MaterialTheme.colorScheme.onPrimary
                                } else {
                                    MaterialTheme.colorScheme.onSurface
                                },
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun GoalContextNote(
    count: Int,
    recommendedCount: Int,
) {
    val isRecommended = count == recommendedCount
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        color = MaterialTheme.colorScheme.surfaceContainerLow.copy(alpha = 0.82f),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.42f)),
    ) {
        Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 13.dp)) {
            Text(
                text = stringResource(
                    if (isRecommended) {
                        R.string.onboarding_goal_hadith_note
                    } else {
                        R.string.onboarding_goal_custom_note
                    },
                ),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(modifier = Modifier.height(6.dp))
            Text(
                text = stringResource(
                    if (isRecommended) {
                        R.string.onboarding_goalintro_hadith_ref
                    } else {
                        R.string.onboarding_goal_custom_label
                    },
                ),
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
                color = greenAccent(),
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

@Composable
private fun StepperButton(
    icon: ImageVector,
    contentDescription: String,
    enabled: Boolean = true,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Surface(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier.size(52.dp),
        shape = RoundedCornerShape(18.dp),
        color = if (enabled) MaterialTheme.colorScheme.surface else MaterialTheme.colorScheme.surface.copy(alpha = 0.58f),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.55f)),
    ) {
        Box(contentAlignment = Alignment.Center) {
            Icon(
                imageVector = icon,
                contentDescription = contentDescription,
                modifier = Modifier.size(20.dp),
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = if (enabled) 1f else 0.35f),
            )
        }
    }
}
