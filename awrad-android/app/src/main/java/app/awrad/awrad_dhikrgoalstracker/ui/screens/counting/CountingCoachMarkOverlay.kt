package app.awrad.awrad_dhikrgoalstracker.ui.screens.counting

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import app.awrad.awrad_dhikrgoalstracker.R

/** Screen-space bounds (px, relative to root) of the elements the guide highlights. */
data class CoachMarkTargets(
    val countButton: Rect? = null,
    val heroPanel: Rect? = null,
    val sessionTargetButton: Rect? = null,
    val historyButton: Rect? = null,
    val audioButton: Rect? = null,
)

private data class CoachStep(
    val target: Rect?,
    val circle: Boolean,
    val titleRes: Int,
    val bodyRes: Int,
)

/** Counts the first run requires before the tap-to-count and audio hints advance. */
private const val REQUIRED_COUNTS = 3

/**
 * First-run spotlight guide for the counting screen. Deliberately intercepts NO
 * pointer input — the scrim is drawn but never clickable — so the user's first
 * real taps land on the actual count button beneath it and are counted for real.
 * The tap-to-count hint advances once [REQUIRED_COUNTS] real taps register, and the
 * audio hint finishes the guide once audio counting reaches [REQUIRED_COUNTS].
 */
@Composable
fun CountingCoachMarkOverlay(
    targets: CoachMarkTargets,
    hasAudio: Boolean,
    isAudioMode: Boolean,
    currentCount: Long,
    onFinished: () -> Unit,
) {
    val steps = remember(targets, hasAudio) {
        buildList {
            add(
                CoachStep(
                    target = targets.countButton,
                    circle = true,
                    titleRes = R.string.coach_tap_title,
                    bodyRes = R.string.coach_tap_body,
                ),
            )
            add(
                CoachStep(
                    target = targets.heroPanel,
                    circle = false,
                    titleRes = R.string.coach_progress_title,
                    bodyRes = R.string.coach_progress_body,
                ),
            )
            if (targets.sessionTargetButton != null) {
                add(
                    CoachStep(
                        target = targets.sessionTargetButton,
                        circle = false,
                        titleRes = R.string.coach_session_title,
                        bodyRes = R.string.coach_session_body,
                    ),
                )
            }
            if (targets.historyButton != null) {
                add(
                    CoachStep(
                        target = targets.historyButton,
                        circle = false,
                        titleRes = R.string.coach_history_title,
                        bodyRes = R.string.coach_history_body,
                    ),
                )
            }
            if (hasAudio && targets.audioButton != null) {
                add(
                    CoachStep(
                        target = targets.audioButton,
                        circle = false,
                        titleRes = R.string.coach_audio_title,
                        bodyRes = R.string.coach_audio_body,
                    ),
                )
            }
        }
    }

    var index by remember { mutableIntStateOf(0) }
    val step = steps.getOrNull(index) ?: return
    val isLast = index >= steps.lastIndex

    // Count baseline captured when the current hint becomes active, so each
    // count-gated hint measures only the taps made while it is on screen.
    val stepBaseline = remember(index) { currentCount }
    val countsThisStep = (currentCount - stepBaseline).coerceAtLeast(0L).toInt()

    val isCountStep = index == 0
    val isAudioStep = hasAudio && index == steps.lastIndex
    val isCountGated = isCountStep || isAudioStep

    // Tap-to-count hint advances after REQUIRED_COUNTS real taps; the audio hint
    // finishes the guide once audio counting reaches REQUIRED_COUNTS.
    LaunchedEffect(countsThisStep, isAudioMode) {
        when {
            isCountStep && countsThisStep >= REQUIRED_COUNTS -> index += 1
            isAudioStep && isAudioMode && countsThisStep >= REQUIRED_COUNTS -> onFinished()
        }
    }

    val pulse = rememberInfiniteTransition(label = "coachPulse")
    val pulseDp by pulse.animateFloat(
        initialValue = 0f,
        targetValue = 6f,
        animationSpec = infiniteRepeatable(
            animation = tween(900, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "coachPulseDp",
    )

    // Animate the spotlight center/extent so it travels smoothly between hints.
    val rect = step.target
    val targetCx = rect?.center?.x ?: 0f
    val targetCy = rect?.center?.y ?: 0f
    val cx by animateFloatAsState(targetCx, tween(420, easing = FastOutSlowInEasing), label = "coachCx")
    val cy by animateFloatAsState(targetCy, tween(420, easing = FastOutSlowInEasing), label = "coachCy")
    val halfW by animateFloatAsState(
        (rect?.width ?: 0f) / 2f,
        tween(420, easing = FastOutSlowInEasing),
        label = "coachHalfW",
    )
    val halfH by animateFloatAsState(
        (rect?.height ?: 0f) / 2f,
        tween(420, easing = FastOutSlowInEasing),
        label = "coachHalfH",
    )

    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        val screenHeightPx = constraints.maxHeight.toFloat()
        val cardAtBottom = cy < screenHeightPx * 0.55f

        // Scrim with a "punched-out" spotlight hole.
        Canvas(
            modifier = Modifier
                .fillMaxSize()
                .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen },
        ) {
            drawRect(color = Color.Black.copy(alpha = 0.62f))
            if (rect != null) {
                val pad = 12.dp.toPx() + pulseDp.dp.toPx()
                if (step.circle) {
                    drawCircle(
                        color = Color.Transparent,
                        radius = maxOf(halfW, halfH) + pad,
                        center = Offset(cx, cy),
                        blendMode = BlendMode.Clear,
                    )
                } else {
                    val w = halfW * 2 + pad * 2
                    val h = halfH * 2 + pad * 2
                    drawRoundRect(
                        color = Color.Transparent,
                        topLeft = Offset(cx - w / 2f, cy - h / 2f),
                        size = Size(w, h),
                        cornerRadius = androidx.compose.ui.geometry.CornerRadius(20.dp.toPx()),
                        blendMode = BlendMode.Clear,
                    )
                }
            }
        }

        // Skip control, always available, top-trailing.
        TextButton(
            onClick = onFinished,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(top = 12.dp, end = 8.dp),
        ) {
            Text(
                text = stringResource(R.string.coach_skip),
                color = Color.White.copy(alpha = 0.85f),
            )
        }

        // Hint card placed opposite the spotlight so it never covers the target.
        Surface(
            modifier = Modifier
                .align(if (cardAtBottom) Alignment.BottomCenter else Alignment.TopCenter)
                .padding(horizontal = 24.dp, vertical = 64.dp)
                .fillMaxWidth(),
            shape = RoundedCornerShape(24.dp),
            color = MaterialTheme.colorScheme.surface,
        ) {
            Column(modifier = Modifier.padding(20.dp)) {
                Text(
                    text = stringResource(step.titleRes),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = stringResource(step.bodyRes),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(modifier = Modifier.height(16.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "${index + 1}/${steps.size}",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(modifier = Modifier.weight(1f))
                    if (isCountGated) {
                        // No advance button: this hint completes only once the user
                        // has counted REQUIRED_COUNTS for real.
                        Text(
                            text = stringResource(
                                R.string.coach_count_progress,
                                countsThisStep.coerceAtMost(REQUIRED_COUNTS),
                                REQUIRED_COUNTS,
                            ),
                            style = MaterialTheme.typography.labelLarge,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.primary,
                        )
                    } else {
                        Button(
                            onClick = {
                                if (isLast) onFinished() else index += 1
                            },
                            shape = RoundedCornerShape(16.dp),
                        ) {
                            Text(
                                text = if (isLast) {
                                    stringResource(R.string.coach_done)
                                } else {
                                    stringResource(R.string.coach_next)
                                },
                            )
                        }
                    }
                }
            }
        }
    }
}
