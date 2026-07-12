package app.awrad.awrad_dhikrgoalstracker.ui.screens.onboarding

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
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
        icon = {
            AwradLogoMark(modifier = Modifier.size(96.dp))
        },
        title = stringResource(R.string.onboarding_goal_title),
        subtitle = stringResource(R.string.onboarding_goal_subtitle),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            AnimatedEntry(delayMillis = 120) {
                GoalCard(preset = preset, count = count, onCountChanged = onCountChanged)
            }

            AnimatedEntry(delayMillis = 220) {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        text = stringResource(R.string.onboarding_goal_hadith_note),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 4.dp),
                    )
                    Spacer(modifier = Modifier.height(10.dp))
                    HadithReferenceChip()
                }
            }
        }
    }
}

/** Non-selectable presentation of the single starter goal, with an inline count stepper. */
@Composable
private fun GoalCard(
    preset: FirstGoalPreset,
    count: Int,
    onCountChanged: (Int) -> Unit,
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        color = greenContainerColor(),
        border = BorderStroke(1.5.dp, greenAccent()),
    ) {
        Column(modifier = Modifier.padding(18.dp)) {
            Text(
                text = preset.arabic,
                fontFamily = NotoNaskhArabicFontFamily,
                style = MaterialTheme.typography.headlineSmall,
                lineHeight = 44.sp,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Spacer(modifier = Modifier.height(6.dp))
            Text(
                text = stringResource(preset.nameRes),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = stringResource(preset.meaningRes),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(modifier = Modifier.height(14.dp))
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
            Spacer(modifier = Modifier.height(14.dp))
            CountStepper(count = count, onCountChanged = onCountChanged)
        }
    }
}

@Composable
private fun CountStepper(
    count: Int,
    onCountChanged: (Int) -> Unit,
) {
    Column {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = stringResource(R.string.onboarding_goal_count_label),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                StepperButton(
                    icon = Icons.Filled.Remove,
                    contentDescription = stringResource(R.string.onboarding_goal_decrease),
                    onClick = { onCountChanged(count - 1) },
                )
                Text(
                    text = count.toString(),
                    modifier = Modifier
                        .defaultMinSize(minWidth = 56.dp)
                        .padding(horizontal = 8.dp),
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                    textAlign = TextAlign.Center,
                )
                StepperButton(
                    icon = Icons.Filled.Add,
                    contentDescription = stringResource(R.string.onboarding_goal_increase),
                    onClick = { onCountChanged(count + 1) },
                )
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            FirstGoalPresets.quickCounts.forEach { value ->
                val active = value == count
                Surface(
                    modifier = Modifier
                        .weight(1f)
                        .clickable { onCountChanged(value) },
                    shape = RoundedCornerShape(14.dp),
                    color = if (active) greenAccent() else MaterialTheme.colorScheme.surfaceContainerHighest,
                ) {
                    Text(
                        text = value.toString(),
                        modifier = Modifier.padding(vertical = 10.dp),
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.SemiBold,
                        textAlign = TextAlign.Center,
                        color = if (active) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface,
                    )
                }
            }
        }
    }
}

@Composable
private fun StepperButton(
    icon: ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
) {
    Surface(
        modifier = Modifier.size(40.dp).clickable(onClick = onClick),
        shape = CircleShape,
        color = MaterialTheme.colorScheme.surfaceContainerHighest,
    ) {
        Box(contentAlignment = Alignment.Center) {
            Icon(
                imageVector = icon,
                contentDescription = contentDescription,
                modifier = Modifier.size(20.dp),
                tint = MaterialTheme.colorScheme.onSurface,
            )
        }
    }
}
