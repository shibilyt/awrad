package app.awrad.awrad_dhikrgoalstracker.ui.screens.onboarding

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.ui.theme.NotoNaskhArabicFontFamily
import kotlinx.coroutines.delay

// The opening unfolds in three beats: Bismillah, the app reveal, then the
// invitation to begin. A tap anywhere fast-forwards to the invitation.
private const val PHASE_BISMILLAH = 0
private const val PHASE_REVEAL = 1
private const val PHASE_READY = 2

private const val BISMILLAH_HOLD_MS = 3100L
private const val REVEAL_HOLD_MS = 1200L

@Composable
internal fun OpeningScene(
    onBegin: () -> Unit,
) {
    var phase by rememberSaveable { mutableIntStateOf(PHASE_BISMILLAH) }

    LaunchedEffect(phase) {
        when (phase) {
            PHASE_BISMILLAH -> {
                delay(BISMILLAH_HOLD_MS)
                phase = PHASE_REVEAL
            }
            PHASE_REVEAL -> {
                delay(REVEAL_HOLD_MS)
                phase = PHASE_READY
            }
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
            ) {
                if (phase < PHASE_READY) phase = PHASE_READY
            },
    ) {
        OpeningGlow(modifier = Modifier.fillMaxSize())

        // Beat 1 — Bismillah, alone in silence.
        AnimatedVisibility(
            visible = phase == PHASE_BISMILLAH,
            modifier = Modifier.align(Alignment.Center),
            enter = fadeIn(tween(1400, easing = FastOutSlowInEasing)) +
                scaleIn(initialScale = 0.94f, animationSpec = tween(1400, easing = FastOutSlowInEasing)),
            exit = fadeOut(tween(500)) + slideOutVertically(tween(500)) { -it / 12 },
        ) {
            BismillahBlock()
        }

        // Beat 2 — the app steps forward.
        AnimatedVisibility(
            visible = phase >= PHASE_REVEAL,
            modifier = Modifier.align(Alignment.Center),
            enter = fadeIn(tween(900, delayMillis = 250)) +
                scaleIn(initialScale = 0.92f, animationSpec = tween(900, delayMillis = 250, easing = FastOutSlowInEasing)),
        ) {
            WelcomeBlock()
        }

        // Beat 3 — the invitation.
        AnimatedVisibility(
            visible = phase == PHASE_READY,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(horizontal = 28.dp, vertical = 40.dp),
            enter = fadeIn(tween(600, delayMillis = 150)) +
                slideInVertically(tween(600, delayMillis = 150)) { it / 3 },
        ) {
            Button(
                onClick = onBegin,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                shape = RoundedCornerShape(22.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = greenAccent(),
                    contentColor = MaterialTheme.colorScheme.onPrimary,
                ),
            ) {
                Text(
                    text = stringResource(R.string.onboarding_begin),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }
    }
}

@Composable
private fun BismillahBlock() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = stringResource(R.string.onboarding_bismillah),
            fontFamily = NotoNaskhArabicFontFamily,
            fontSize = 34.sp,
            lineHeight = 64.sp,
            color = MaterialTheme.colorScheme.primary,
            textAlign = TextAlign.Center,
        )

        Spacer(modifier = Modifier.height(18.dp))

        OrnamentDivider()

        // In the Arabic locale the line above already IS the translation, so
        // locales may blank this string to hide the duplicate.
        val translation = stringResource(R.string.onboarding_bismillah_translation)
        if (translation.isNotBlank()) {
            Spacer(modifier = Modifier.height(18.dp))

            Text(
                text = translation,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }
    }
}

@Composable
private fun WelcomeBlock() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(contentAlignment = Alignment.Center) {
            LogoHalo(modifier = Modifier.size(196.dp))
            AwradLogoMark(modifier = Modifier.size(148.dp))
        }

        Spacer(modifier = Modifier.height(30.dp))

        Text(
            text = stringResource(R.string.onboarding_welcome_salam),
            style = MaterialTheme.typography.labelLarge.copy(letterSpacing = 2.sp),
            color = greenAccent(),
            textAlign = TextAlign.Center,
        )

        Spacer(modifier = Modifier.height(10.dp))

        Text(
            text = stringResource(R.string.onboarding_welcome_headline),
            style = MaterialTheme.typography.displaySmall,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary,
            textAlign = TextAlign.Center,
        )

        Spacer(modifier = Modifier.height(10.dp))

        Text(
            text = stringResource(R.string.onboarding_app_tagline),
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )
    }
}

/** A slow-breathing soft halo behind the logo. */
@Composable
private fun LogoHalo(modifier: Modifier = Modifier) {
    val transition = rememberInfiniteTransition(label = "logoHalo")
    val breath by transition.animateFloat(
        initialValue = 0.9f,
        targetValue = 1.06f,
        animationSpec = infiniteRepeatable(
            animation = tween(2600, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "logoHaloBreath",
    )
    val soft = greenContainerColor()
    Canvas(
        modifier = modifier.graphicsLayer {
            scaleX = breath
            scaleY = breath
        },
    ) {
        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(soft.copy(alpha = 0.85f), soft.copy(alpha = 0f)),
            ),
            radius = size.minDimension / 2f,
        )
    }
}

@Composable
internal fun OrnamentDivider(modifier: Modifier = Modifier) {
    val accent = greenAccent()
    Canvas(modifier = modifier.width(72.dp).height(10.dp)) {
        val cy = size.height / 2f
        val diamond = 3.4.dp.toPx()
        // Center diamond flanked by two thin lines.
        drawLine(
            color = accent.copy(alpha = 0.55f),
            start = androidx.compose.ui.geometry.Offset(0f, cy),
            end = androidx.compose.ui.geometry.Offset(size.width / 2f - diamond * 2.4f, cy),
            strokeWidth = 1.6.dp.toPx(),
        )
        drawLine(
            color = accent.copy(alpha = 0.55f),
            start = androidx.compose.ui.geometry.Offset(size.width / 2f + diamond * 2.4f, cy),
            end = androidx.compose.ui.geometry.Offset(size.width, cy),
            strokeWidth = 1.6.dp.toPx(),
        )
        rotate(degrees = 45f, pivot = androidx.compose.ui.geometry.Offset(size.width / 2f, cy)) {
            drawRect(
                color = accent,
                topLeft = androidx.compose.ui.geometry.Offset(size.width / 2f - diamond / 2f, cy - diamond / 2f),
                size = androidx.compose.ui.geometry.Size(diamond, diamond),
            )
        }
    }
}

/** Full-bleed radial wash that gives the opening a lit-from-within feel. */
@Composable
private fun OpeningGlow(modifier: Modifier = Modifier) {
    val accent = greenAccent()
    Canvas(modifier = modifier.clip(RoundedCornerShape(0.dp))) {
        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(accent.copy(alpha = 0.14f), accent.copy(alpha = 0f)),
                center = androidx.compose.ui.geometry.Offset(size.width / 2f, size.height * 0.42f),
                radius = size.minDimension * 0.85f,
            ),
            center = androidx.compose.ui.geometry.Offset(size.width / 2f, size.height * 0.42f),
            radius = size.minDimension * 0.85f,
        )
    }
}
