package app.awrad.feature.library

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
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
import app.awrad.core.domain.dhikr.Reference
import app.awrad.core.domain.dhikr.textIn
import java.util.Locale

/**
 * The Arabic card (components.md, "Dhikr detail screen"): a `surface` card with the Arabic centred, by kind:
 * - Qur'an: one ayah per line in `quran`, then its reference ("Qur'an 112:1–4") in `caption`;
 * - a name of Allah: the name in `nameOfAllah`, then its meaning in `title`;
 * - the others: the Arabic in `quran`.
 * The player bar sits at the bottom when the dhikr has a recording.
 */
@Composable
internal fun ArabicCard(
    dhikr: Dhikr,
    language: ContentLanguage,
    playback: PlaybackState,
    onTogglePlayback: () -> Unit,
    modifier: Modifier = Modifier,
) {
    AwradCard(modifier = modifier) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.sm),
        ) {
            when (dhikr.kind) {
                DhikrKind.NAME_OF_ALLAH -> {
                    CentredText(text = dhikr.arabic, style = AwradTheme.type.nameOfAllah)
                    CentredText(text = dhikr.textIn(language).translation, style = AwradTheme.type.title)
                }
                DhikrKind.QURAN -> {
                    dhikr.arabicLines.forEach { CentredText(text = it, style = AwradTheme.type.quran) }
                    dhikr.references.filterIsInstance<Reference.Quran>().firstOrNull()?.let { reference ->
                        Text(
                            text = referenceLabel(reference).text,
                            style = AwradTheme.type.caption,
                            color = AwradTheme.colors.onSurfaceVariant,
                            textAlign = TextAlign.Center,
                        )
                    }
                }
                DhikrKind.DHIKR, DhikrKind.DUA, DhikrKind.SALAWAT ->
                    dhikr.arabicLines.forEach { CentredText(text = it, style = AwradTheme.type.quran) }
            }
        }
        dhikr.audio?.let { PlayerBar(playback = playback, onToggle = onTogglePlayback) }
    }
}

@Composable
private fun CentredText(text: String, style: TextStyle, modifier: Modifier = Modifier) {
    Text(
        text = text,
        modifier = modifier,
        style = style,
        color = AwradTheme.colors.onSurface,
        textAlign = TextAlign.Center,
    )
}

/**
 * The audio player bar (components.md, "Audio player bar"): a round play/pause button (a spinner while it
 * connects), a progress line, then the time ("0:14 / 0:26", or the elapsed time alone while the length is
 * unknown). If the recording fails, a message replaces the line and the time, and play retries.
 */
@Composable
internal fun PlayerBar(playback: PlaybackState, onToggle: () -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(AwradTheme.spacing.md),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        AwradRoundButton(
            icon = if (playback.isPlaying) AwradIcons.Pause else AwradIcons.Play,
            contentDescription = stringResource(
                if (playback.isPlaying) R.string.library_pause else R.string.library_play,
            ),
            onClick = onToggle,
            isLoading = playback.status == PlaybackStatus.LOADING,
        )
        if (playback.status == PlaybackStatus.FAILED) {
            Text(
                text = stringResource(R.string.library_audio_failed),
                modifier = Modifier
                    .weight(1f)
                    .semantics { liveRegion = LiveRegionMode.Polite },
                style = AwradTheme.type.caption,
                color = AwradTheme.colors.error,
            )
        } else {
            AwradLinearProgress(progress = { playback.progress ?: 0f }, modifier = Modifier.weight(1f))
            Text(
                text = elapsed(playback),
                style = AwradTheme.type.caption,
                color = AwradTheme.colors.onSurfaceVariant,
                maxLines = 1,
            )
        }
    }
}

/** "0:12 / 0:45", or just the elapsed time while the length is unknown. */
@Composable
private fun elapsed(playback: PlaybackState): String {
    val locale = LocalConfiguration.current.locales[0]
    val position = clock(playback.positionMs, locale)
    val duration = playback.durationMs ?: return position
    return stringResource(R.string.library_audio_elapsed, position, clock(duration, locale))
}

/** Minutes, unpadded, and seconds: "0:14", in [locale]'s digits. */
private fun clock(millis: Long, locale: Locale): String {
    val seconds = millis / MILLIS_PER_SECOND
    return String.format(locale, "%d:%02d", seconds / SECONDS_PER_MINUTE, seconds % SECONDS_PER_MINUTE)
}

private const val MILLIS_PER_SECOND = 1_000L
private const val SECONDS_PER_MINUTE = 60L
