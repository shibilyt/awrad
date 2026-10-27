package app.awrad.feature.library

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.stringResource
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.core.designsystem.component.AwradCard
import app.awrad.core.designsystem.component.AwradChip
import app.awrad.core.designsystem.component.AwradSectionTitle
import app.awrad.core.designsystem.component.AwradTextButton
import app.awrad.core.designsystem.component.AwradTopBar
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.core.domain.audio.PlaybackState
import app.awrad.core.domain.dhikr.CatalogTag
import app.awrad.core.domain.dhikr.ContentLanguage
import app.awrad.core.domain.dhikr.Dhikr
import app.awrad.core.domain.dhikr.ReferenceLabel
import app.awrad.core.domain.dhikr.Virtue

@Composable
internal fun DhikrDetailRoute(
    dhikrKey: String,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: DhikrDetailViewModel = hiltViewModel<DhikrDetailViewModel, DhikrDetailViewModel.Factory>(
        key = dhikrKey,
        creationCallback = { it.create(dhikrKey) },
    ),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    // Leaving the page (another page on top, another app, the screen off) pauses the recording.
    LifecycleEventEffect(Lifecycle.Event.ON_STOP) { viewModel.onAction(DhikrDetailAction.Pause) }
    DhikrDetailScreen(state = state, onAction = viewModel::onAction, onBack = onBack, modifier = modifier)
}

/**
 * A top bar with Back and the title, then the dhikr rendered by its kind, its recording (when it has one), its
 * tags and its virtues with their references.
 */
@Composable
internal fun DhikrDetailScreen(
    state: DhikrDetailUiState,
    onAction: (DhikrDetailAction) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val language = currentContentLanguage()
    val dhikr = state.dhikr
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(AwradTheme.colors.background)
            .statusBarsPadding(),
    ) {
        AwradTopBar(title = dhikr?.title?.localized(language), onBack = onBack)
        when {
            dhikr != null -> DhikrDetailContent(
                dhikr = dhikr,
                language = language,
                playback = state.playback,
                onTogglePlayback = { onAction(DhikrDetailAction.TogglePlayback) },
            )
            !state.isLoading -> MissingContent()
        }
    }
}

@Composable
private fun DhikrDetailContent(
    dhikr: Dhikr,
    language: ContentLanguage,
    playback: PlaybackState,
    onTogglePlayback: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val spacing = AwradTheme.spacing
    val navigationBar = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = spacing.pageMargin)
            .padding(top = spacing.sm, bottom = spacing.sectionGap + navigationBar),
        verticalArrangement = Arrangement.spacedBy(spacing.sectionGap),
    ) {
        DhikrTextByKind(dhikr = dhikr, language = language)
        dhikr.audio?.let { AudioControl(playback = playback, onToggle = onTogglePlayback) }
        if (dhikr.tags.isNotEmpty()) Tags(tags = dhikr.tags, language = language)
        if (dhikr.virtues.isNotEmpty()) Virtues(virtues = dhikr.virtues, language = language)
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun Tags(tags: List<CatalogTag>, language: ContentLanguage, modifier: Modifier = Modifier) {
    FlowRow(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(AwradTheme.spacing.sm),
        verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.sm),
    ) {
        tags.forEach { AwradChip(text = it.title.localized(language)) }
    }
}

/** "Virtues", then a card per virtue: its text, and under it each reference it cites. */
@Composable
private fun Virtues(virtues: List<Virtue>, language: ContentLanguage, modifier: Modifier = Modifier) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.rowGap)) {
        AwradSectionTitle(text = stringResource(R.string.library_virtues))
        virtues.forEach { virtue ->
            AwradCard(spacing = AwradTheme.spacing.sm) {
                Text(text = virtue.text.localized(language), style = AwradTheme.type.body)
                virtue.references.forEach { reference -> ReferenceLine(label = referenceLabel(reference)) }
            }
        }
    }
}

/** One citation in `caption`, `onSurfaceVariant`; a link opens in the browser. */
@Composable
private fun ReferenceLine(label: ReferenceLabel, modifier: Modifier = Modifier) {
    Column(modifier = modifier) {
        Text(text = label.text, style = AwradTheme.type.caption, color = AwradTheme.colors.onSurfaceVariant)
        label.url?.let { url ->
            val uriHandler = LocalUriHandler.current
            AwradTextButton(text = stringResource(R.string.library_open_source), onClick = { uriHandler.openUri(url) })
        }
    }
}
