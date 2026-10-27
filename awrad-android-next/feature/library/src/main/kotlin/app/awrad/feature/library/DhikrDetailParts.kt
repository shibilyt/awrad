package app.awrad.feature.library

import android.text.format.DateUtils
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import app.awrad.core.designsystem.component.AwradCard
import app.awrad.core.designsystem.component.AwradLinearProgress
import app.awrad.core.designsystem.component.AwradRoundButton
import app.awrad.core.designsystem.icon.AwradIcons
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.core.domain.audio.PlaybackState
import app.awrad.core.domain.audio.PlaybackStatus
import app.awrad.core.domain.dhikr.ContentLanguage
import app.awrad.core.domain.dhikr.Dhikr
import app.awrad.core.domain.dhikr.DhikrKind
import app.awrad.core.domain.dhikr.DhikrText
import app.awrad.core.domain.dhikr.Reference
import app.awrad.core.domain.dhikr.textIn

/**
 * The dhikr's text by its kind (docs/slices/03a-dhikr-catalog.md, "Rendering by kind"):
 * - Qur'an: one ayah per line in `quran`, then its reference ("Qur'an 112:1–4");
 * - a name of Allah: the name large and centred, then its meaning;
 * - the others: the Arabic in `quran`.
 * The transliteration (`body`, `onSurfaceVariant`; none in Arabic) and the translation (`body`) follow.
 */
@Composable
internal fun DhikrTextByKind(dhikr: Dhikr, language: ContentLanguage, modifier: Modifier = Modifier) {
    val text = dhikr.textIn(language)
    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.rowGap),
    ) {
        when (dhikr.kind) {
            DhikrKind.NAME_OF_ALLAH -> NameOfAllah(dhikr = dhikr, text = text)
            DhikrKind.QURAN -> {
                ArabicLines(lines = dhikr.arabicLines)
                dhikr.references.filterIsInstance<Reference.Quran>().firstOrNull()?.let { reference ->
                    Text(
                        text = referenceLabel(reference).text,
                        style = AwradTheme.type.label,
                        color = AwradTheme.colors.onSurfaceVariant,
                        textAlign = TextAlign.Center,
                    )
                }
                Meaning(text = text)
            }
            DhikrKind.DHIKR, DhikrKind.DUA, DhikrKind.SALAWAT -> {
                ArabicLines(lines = dhikr.arabicLines)
                Meaning(text = text)
            }
        }
    }
}

/** Each line (an ayah, for Qur'an) centred in `quran`. */
@Composable
private fun ArabicLines(lines: List<String>, modifier: Modifier = Modifier) {
    Column(modifier = modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        lines.forEach { line ->
            Text(
                text = line,
                style = AwradTheme.type.quran,
                color = AwradTheme.colors.onSurface,
                textAlign = TextAlign.Center,
            )
        }
    }
}

/** The transliteration, then the translation, from the start. */
@Composable
private fun Meaning(text: DhikrText, modifier: Modifier = Modifier) {
    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.sm)) {
        text.transliteration?.let {
            Text(text = it, style = AwradTheme.type.body, color = AwradTheme.colors.onSurfaceVariant)
        }
        Text(text = text.translation, style = AwradTheme.type.body, color = AwradTheme.colors.onSurface)
    }
}

/** The name in the `quran` face at the `largeTitle` size, its transliteration, then its meaning in `title`. */
@Composable
private fun NameOfAllah(dhikr: Dhikr, text: DhikrText, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.sm),
    ) {
        Text(
            text = dhikr.arabic,
            style = largeArabic(),
            color = AwradTheme.colors.onSurface,
            textAlign = TextAlign.Center,
        )
        text.transliteration?.let {
            Text(
                text = it,
                style = AwradTheme.type.body,
                color = AwradTheme.colors.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }
        Text(
            text = text.translation,
            style = AwradTheme.type.title,
            color = AwradTheme.colors.onSurface,
            textAlign = TextAlign.Center,
        )
    }
}

/** `quran` scaled up to `largeTitle`'s size, its line height in proportion (the tokens have no larger Arabic). */
@Composable
private fun largeArabic(): TextStyle {
    val quran = AwradTheme.type.quran
    val size = AwradTheme.type.largeTitle.fontSize
    return quran.copy(fontSize = size, lineHeight = quran.lineHeight * (size.value / quran.fontSize.value))
}

/**
 * The recording in a card: a round play/pause button, then a progress bar with the elapsed and total time. While
 * it connects the bar runs without a length; if it fails, a message says so and play retries.
 */
@Composable
internal fun AudioControl(playback: PlaybackState, onToggle: () -> Unit, modifier: Modifier = Modifier) {
    AwradCard(modifier = modifier) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(AwradTheme.spacing.md),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            AwradRoundButton(
                icon = if (playback.isPlaying) AwradIcons.Pause else AwradIcons.Play,
                contentDescription = stringResource(
                    if (playback.isPlaying) R.string.library_pause else R.string.library_play,
                ),
                onClick = onToggle,
            )
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.sm),
            ) {
                val progress = playback.progress
                if (playback.status == PlaybackStatus.LOADING && progress == null) {
                    AwradLinearProgress()
                } else {
                    AwradLinearProgress(progress = { progress ?: 0f })
                }
                PlaybackLine(playback = playback)
            }
        }
    }
}

@Composable
private fun PlaybackLine(playback: PlaybackState, modifier: Modifier = Modifier) {
    val (text, color) = when (playback.status) {
        PlaybackStatus.FAILED -> stringResource(R.string.library_audio_failed) to AwradTheme.colors.error
        PlaybackStatus.LOADING -> stringResource(R.string.library_audio_loading) to AwradTheme.colors.onSurfaceVariant
        else -> elapsed(playback) to AwradTheme.colors.onSurfaceVariant
    }
    Text(
        text = text,
        modifier = modifier.semantics {
            if (playback.status == PlaybackStatus.FAILED) liveRegion = LiveRegionMode.Polite
        },
        style = AwradTheme.type.caption,
        color = color,
    )
}

/** "0:12 / 0:45", or just the elapsed time while the length is unknown. */
@Composable
private fun elapsed(playback: PlaybackState): String {
    val position = DateUtils.formatElapsedTime(playback.positionMs / MILLIS_PER_SECOND)
    val duration = playback.durationMs ?: return position
    val total = DateUtils.formatElapsedTime(duration / MILLIS_PER_SECOND)
    return stringResource(R.string.library_audio_elapsed, position, total)
}

private const val MILLIS_PER_SECOND = 1_000L
