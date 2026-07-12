package app.awrad.awrad_dhikrgoalstracker.ui.screens.onboarding

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.ui.theme.OnSageGreenContainer
import app.awrad.awrad_dhikrgoalstracker.ui.theme.SageGreen
import app.awrad.awrad_dhikrgoalstracker.ui.theme.SageGreenContainer
import app.awrad.awrad_dhikrgoalstracker.ui.theme.SageGreenDark
import app.awrad.awrad_dhikrgoalstracker.ui.theme.SageGreenLight
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme
import androidx.compose.ui.graphics.vector.ImageVector
import kotlin.math.sin

// ─── Accent color helpers for dark/light mode ────────────────────────────────

@Composable
internal fun greenAccent(): Color = if (isAwradDarkTheme()) SageGreenLight else SageGreen

@Composable
internal fun greenContainerColor(): Color =
    if (isAwradDarkTheme()) SageGreenDark.copy(alpha = 0.3f) else SageGreenContainer

@Composable
internal fun onGreenContainerColor(): Color =
    if (isAwradDarkTheme()) SageGreenLight else OnSageGreenContainer

// ─── Staggered entrance animation helper ────────────────────────────────────

@Composable
internal fun AnimatedEntry(
    delayMillis: Int,
    content: @Composable () -> Unit,
) {
    val visible = remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { visible.value = true }

    AnimatedVisibility(
        visible = visible.value,
        enter = fadeIn(tween(420, delayMillis = delayMillis)) + slideInVertically(
            initialOffsetY = { it / 8 },
            animationSpec = tween(420, delayMillis = delayMillis),
        ),
    ) {
        content()
    }
}

// ─── Cinematic backdrop ──────────────────────────────────────────────────────

/**
 * Simple, static full-bleed gradient backdrop behind the scene content.
 * A soft sage→background vertical wash — no animation, nothing fancy.
 */
@Composable
internal fun CinematicBackdrop(
    stepIndex: Int,
    totalSteps: Int,
    modifier: Modifier = Modifier,
) {
    val accent = greenAccent()
    val background = MaterialTheme.colorScheme.background

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(
                        accent.copy(alpha = 0.10f),
                        background,
                        background,
                    ),
                ),
            ),
    )
}

// ─── Progress beads (misbaha strand) ─────────────────────────────────────────

@Composable
internal fun OnboardingProgressBeads(
    currentStep: Int,
    totalSteps: Int,
    modifier: Modifier = Modifier,
) {
    val accent = greenAccent()
    val track = MaterialTheme.colorScheme.outlineVariant
    val pulse = rememberInfiniteTransition(label = "beadPulse")
    val halo by pulse.animateFloat(
        initialValue = 0.45f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1100, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "beadHalo",
    )

    Canvas(
        modifier = modifier
            .size(width = (totalSteps * 16).dp, height = 16.dp),
    ) {
        val n = totalSteps
        val spacing = size.width / n
        val cy = size.height / 2f
        repeat(n) { i ->
            val cx = spacing * (i + 0.5f)
            when {
                i < currentStep -> drawCircle(
                    color = accent,
                    radius = 3.dp.toPx(),
                    center = Offset(cx, cy),
                )
                i == currentStep -> {
                    drawCircle(
                        color = accent.copy(alpha = 0.25f * halo),
                        radius = 7.dp.toPx(),
                        center = Offset(cx, cy),
                    )
                    drawCircle(
                        color = accent,
                        radius = 4.dp.toPx(),
                        center = Offset(cx, cy),
                    )
                }
                else -> drawCircle(
                    color = track,
                    radius = 2.5.dp.toPx(),
                    center = Offset(cx, cy),
                )
            }
        }
    }
}

// ─── Shared selection indicator ──────────────────────────────────────────────

/** Circular check indicator used by selectable option cards. */
@Composable
internal fun OnboardingSelectionDot(selected: Boolean, modifier: Modifier = Modifier) {
    val fill by animateColorAsState(
        targetValue = if (selected) greenAccent() else Color.Transparent,
        animationSpec = tween(160),
        label = "selectionDotFill",
    )
    Surface(
        modifier = modifier.size(24.dp),
        shape = CircleShape,
        color = fill,
        border = if (selected) null else BorderStroke(1.5.dp, MaterialTheme.colorScheme.outlineVariant),
    ) {
        if (selected) {
            Box(contentAlignment = Alignment.Center) {
                Icon(
                    imageVector = Icons.Filled.Check,
                    contentDescription = null,
                    modifier = Modifier.size(15.dp),
                    tint = MaterialTheme.colorScheme.onPrimary,
                )
            }
        }
    }
}

// ─── Shared glyphs ───────────────────────────────────────────────────────────

/** The Awrad app logo (misbaha ring + Arabic mark), theme-aware for light/dark. */
@Composable
internal fun AwradLogoMark(modifier: Modifier = Modifier) {
    Image(
        painter = painterResource(
            id = if (isAwradDarkTheme()) {
                R.drawable.onboarding_logo_dark
            } else {
                R.drawable.onboarding_logo_light
            },
        ),
        contentDescription = null,
        contentScale = ContentScale.Fit,
        modifier = modifier,
    )
}

@Composable
internal fun AudioWaveGlyph(modifier: Modifier = Modifier) {
    val transition = rememberInfiniteTransition(label = "audioWave")
    val phase by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1400, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "audioWavePhase",
    )
    val accent = greenAccent()
    val soft = greenContainerColor()

    Canvas(modifier = modifier) {
        val centerY = size.height / 2f
        val barWidth = 5.dp.toPx()
        val gap = 8.dp.toPx()
        val total = 7
        val startX = (size.width - (total * barWidth + (total - 1) * gap)) / 2f
        drawCircle(color = soft, radius = size.minDimension * 0.42f, center = Offset(size.width / 2f, centerY))
        repeat(total) { index ->
            val wave = sin((phase * Math.PI * 2) + index * 0.75).toFloat()
            val height = (22.dp.toPx() + (wave + 1f) * 13.dp.toPx()).coerceAtLeast(16.dp.toPx())
            val x = startX + index * (barWidth + gap)
            drawLine(
                color = accent.copy(alpha = 0.55f + index * 0.05f),
                start = Offset(x, centerY - height / 2f),
                end = Offset(x, centerY + height / 2f),
                strokeWidth = barWidth,
                cap = StrokeCap.Round,
            )
        }
    }
}

/** [AudioWaveGlyph] wrapped with a sweeping progress arc (0f..1f). */
@Composable
internal fun AudioWaveProgressGlyph(progress: Float, modifier: Modifier = Modifier) {
    val accent = greenAccent()
    val track = greenContainerColor()
    Box(modifier = modifier, contentAlignment = Alignment.Center) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val stroke = 5.dp.toPx()
            val diameter = size.minDimension - stroke
            val topLeft = Offset((size.width - diameter) / 2f, (size.height - diameter) / 2f)
            drawArc(
                color = track,
                startAngle = -90f,
                sweepAngle = 360f,
                useCenter = false,
                topLeft = topLeft,
                size = Size(diameter, diameter),
                style = Stroke(width = stroke, cap = StrokeCap.Round),
            )
            drawArc(
                color = accent,
                startAngle = -90f,
                sweepAngle = 360f * progress.coerceIn(0f, 1f),
                useCenter = false,
                topLeft = topLeft,
                size = Size(diameter, diameter),
                style = Stroke(width = stroke, cap = StrokeCap.Round),
            )
        }
        AudioWaveGlyph(modifier = Modifier.size(72.dp))
    }
}

@Composable
internal fun PrayerTimeGlyph(modifier: Modifier = Modifier) {
    val accent = greenAccent()
    val soft = greenContainerColor()
    Canvas(modifier = modifier) {
        val center = Offset(size.width / 2f, size.height / 2f)
        drawCircle(color = soft, radius = size.minDimension * 0.42f, center = center)
        drawCircle(
            color = accent.copy(alpha = 0.18f),
            radius = size.minDimension * 0.31f,
            center = center,
            style = Stroke(width = 2.dp.toPx()),
        )
        repeat(5) { index ->
            val y = center.y - 24.dp.toPx() + index * 12.dp.toPx()
            val startX = center.x - 28.dp.toPx()
            val endX = center.x + (if (index == 2) 28.dp.toPx() else 18.dp.toPx())
            drawLine(
                color = accent.copy(alpha = if (index == 2) 0.9f else 0.42f),
                start = Offset(startX, y),
                end = Offset(endX, y),
                strokeWidth = 3.dp.toPx(),
                cap = StrokeCap.Round,
            )
        }
    }
}

