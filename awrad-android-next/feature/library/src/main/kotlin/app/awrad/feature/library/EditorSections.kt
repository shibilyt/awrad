package app.awrad.feature.library

import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.key
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import app.awrad.core.designsystem.component.AwradButtonVariant
import app.awrad.core.designsystem.component.AwradCard
import app.awrad.core.designsystem.component.AwradChip
import app.awrad.core.designsystem.component.AwradIconButton
import app.awrad.core.designsystem.component.AwradRoundButton
import app.awrad.core.designsystem.component.AwradRowButton
import app.awrad.core.designsystem.component.AwradSectionTitle
import app.awrad.core.designsystem.component.AwradSegmentedPills
import app.awrad.core.designsystem.component.AwradTextButton
import app.awrad.core.designsystem.component.AwradTextField
import app.awrad.core.designsystem.icon.AwradIcons
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.core.domain.audio.PlaybackStatus
import app.awrad.core.domain.dhikr.ContentLanguage
import app.awrad.core.domain.dhikr.DhikrKind

/**
 * What kept the last save from going through, announced: a problem of the whole dhikr, which no field shows, or
 * "Check the fields marked below". Focusable, so a failed save can move focus (and a screen reader) here.
 */
@Composable
internal fun ProblemsLine(problems: Map<ProblemSpot, EditorProblem>, modifier: Modifier = Modifier) {
    if (problems.isEmpty()) return
    val whole = problems[ProblemSpot.SUMMARY]
    Text(
        text = whole?.let { problemText(it) } ?: stringResource(R.string.editor_problems),
        modifier = modifier
            .focusable()
            .semantics { liveRegion = LiveRegionMode.Polite },
        style = AwradTheme.type.bodySmall,
        color = AwradTheme.colors.error,
    )
}

/** "Kind": one chip per kind, one chosen. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun KindSection(kind: DhikrKind, onAction: (EditorAction) -> Unit, modifier: Modifier = Modifier) {
    EditorSection(title = stringResource(R.string.editor_kind), modifier = modifier) {
        FlowRow(horizontalArrangement = Arrangement.spacedBy(AwradTheme.spacing.sm)) {
            DhikrKind.entries.forEach { option ->
                AwradChip(
                    text = kindName(option),
                    selected = option == kind,
                    onSelectedChange = { onAction(EditorAction.KindChanged(option)) },
                )
            }
        }
    }
}

/** The Arabic text, required, several lines; for Qur'an, one ayah per line. */
@Composable
internal fun ArabicSection(
    state: EditorUiState,
    onAction: (EditorAction) -> Unit,
    targets: ProblemTargets,
    modifier: Modifier = Modifier,
) {
    val problem = state.problems[ProblemSpot.ARABIC]
    AwradTextField(
        value = state.arabic,
        onValueChange = { onAction(EditorAction.ArabicChanged(it)) },
        label = stringResource(R.string.editor_arabic),
        modifier = modifier.problemSpot(targets, ProblemSpot.ARABIC),
        singleLine = false,
        error = problem?.let { problemText(it) },
        supportingText = stringResource(R.string.editor_arabic_hint),
    )
}

/**
 * The title, transliteration and translation in the language the pills pick: compact, one language at a time.
 * Arabic has no transliteration. At least one title is needed, in any language.
 */
@Composable
internal fun TextsSection(
    state: EditorUiState,
    onAction: (EditorAction) -> Unit,
    targets: ProblemTargets,
    modifier: Modifier = Modifier,
) {
    val language = state.shownLanguage
    val languages = ContentLanguage.entries
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.rowGap)) {
        AwradSectionTitle(text = stringResource(R.string.editor_texts))
        AwradSegmentedPills(
            options = languages.map { languageName(it) },
            selectedIndex = languages.indexOf(language),
            onSelect = { onAction(EditorAction.LanguageShown(languages[it])) },
        )
        AwradTextField(
            value = state.titles[language],
            onValueChange = { onAction(EditorAction.TitleChanged(it)) },
            label = stringResource(R.string.editor_title_field, languageName(language)),
            modifier = Modifier.problemSpot(targets, ProblemSpot.TITLE),
            error = state.problems[ProblemSpot.TITLE]?.let { problemText(it) },
            supportingText = stringResource(R.string.editor_title_hint),
        )
        if (language != ContentLanguage.AR) {
            AwradTextField(
                value = state.transliterations[language],
                onValueChange = { onAction(EditorAction.TransliterationChanged(it)) },
                label = stringResource(R.string.editor_transliteration_field, languageName(language)),
                singleLine = false,
            )
        }
        AwradTextField(
            value = state.translations[language],
            onValueChange = { onAction(EditorAction.TranslationChanged(it)) },
            label = stringResource(R.string.editor_translation_field, languageName(language)),
            singleLine = false,
        )
    }
}

/**
 * The recording, kept on this phone only: import an MP3 or M4A (up to 10 MB), then play it, replace it or remove
 * it. A recording made on another device can only be removed here.
 */
@Composable
internal fun AudioSection(
    state: EditorUiState,
    onAction: (EditorAction) -> Unit,
    onPickAudio: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val audio = state.audio
    EditorSection(title = stringResource(R.string.editor_recording), modifier = modifier) {
        if (audio == null) {
            AwradRowButton(
                text = stringResource(R.string.editor_import_recording),
                onClick = onPickAudio,
                variant = AwradButtonVariant.Secondary,
                leadingIcon = AwradIcons.Add,
            )
        } else {
            RecordingCard(audio = audio, state = state, onAction = onAction, onPickAudio = onPickAudio)
        }
        state.audioError?.let { error ->
            Text(
                text = audioErrorText(error),
                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                style = AwradTheme.type.caption,
                color = AwradTheme.colors.error,
            )
        }
        Text(
            text = stringResource(R.string.editor_recording_hint),
            style = AwradTheme.type.caption,
            color = AwradTheme.colors.onSurfaceVariant,
        )
    }
}

/** The recording: play and pause (when it's on this phone), where it is, then Replace and Remove. */
@Composable
private fun RecordingCard(
    audio: AudioField,
    state: EditorUiState,
    onAction: (EditorAction) -> Unit,
    onPickAudio: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val playing = state.playback.isPlaying
    AwradCard(modifier = modifier) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(AwradTheme.spacing.md),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (audio.localUri != null) {
                AwradRoundButton(
                    icon = if (playing) AwradIcons.Pause else AwradIcons.Play,
                    contentDescription = stringResource(if (playing) R.string.library_pause else R.string.library_play),
                    onClick = { onAction(EditorAction.TogglePlayback) },
                    isLoading = state.playback.status == PlaybackStatus.LOADING,
                )
            }
            Text(
                text = stringResource(
                    if (audio.localUri == null) R.string.editor_recording_elsewhere else R.string.editor_recording_here,
                ),
                modifier = Modifier.weight(1f),
                style = AwradTheme.type.body,
                color = AwradTheme.colors.onSurface,
            )
        }
        Row {
            AwradTextButton(text = stringResource(R.string.editor_replace_recording), onClick = onPickAudio)
            AwradTextButton(
                text = stringResource(R.string.editor_remove_recording),
                onClick = { onAction(EditorAction.RemoveAudio) },
                isDestructive = true,
            )
        }
    }
}

/** The dhikr's tags: a chip per tag, on or off. Tags are made and renamed in "Manage tags". */
@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun EditorTagsSection(state: EditorUiState, onAction: (EditorAction) -> Unit, modifier: Modifier = Modifier) {
    EditorSection(title = stringResource(R.string.library_tags), modifier = modifier) {
        if (state.tags.isEmpty()) {
            Text(
                text = stringResource(R.string.editor_tags_empty),
                style = AwradTheme.type.bodySmall,
                color = AwradTheme.colors.onSurfaceVariant,
            )
        }
        FlowRow(horizontalArrangement = Arrangement.spacedBy(AwradTheme.spacing.sm)) {
            state.tags.forEach { tag ->
                key(tag.id.value) {
                    AwradChip(
                        text = tag.name,
                        selected = tag.id in state.selectedTags,
                        onSelectedChange = { onAction(EditorAction.TagToggled(tag.id)) },
                    )
                }
            }
        }
    }
}

@Composable
internal fun EditorSection(title: String, modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.sm)) {
        AwradSectionTitle(text = title)
        content()
    }
}

@Composable
internal fun RemoveButton(onClick: () -> Unit, modifier: Modifier = Modifier) {
    AwradIconButton(
        icon = AwradIcons.Close,
        contentDescription = stringResource(R.string.editor_remove),
        onClick = onClick,
        modifier = modifier,
        tint = AwradTheme.colors.onSurfaceVariant,
    )
}
