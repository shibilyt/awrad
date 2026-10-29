package app.awrad.feature.library

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
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
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.stringResource
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.LocalLifecycleOwner
import app.awrad.core.designsystem.component.AwradCard
import app.awrad.core.designsystem.component.AwradChip
import app.awrad.core.designsystem.component.AwradSectionTitle
import app.awrad.core.designsystem.component.AwradTextButton
import app.awrad.core.designsystem.component.AwradTopBar
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.core.domain.dhikr.ContentLanguage
import app.awrad.core.domain.dhikr.DhikrKind
import app.awrad.core.domain.dhikr.Reference
import app.awrad.core.domain.dhikr.ReferenceLabel
import app.awrad.core.domain.dhikr.Virtue
import app.awrad.core.domain.dhikr.textIn
import app.awrad.core.domain.personal.textIn
import app.awrad.core.domain.sync.ConflictChoice

@Composable
internal fun DhikrDetailRoute(
    dhikrId: String,
    onNavigate: (LibraryDestination) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: DhikrDetailViewModel = hiltViewModel<DhikrDetailViewModel, DhikrDetailViewModel.Factory>(
        key = dhikrId,
        creationCallback = { it.create(dhikrId) },
    ),
) {
    val state by viewModel.state
    // The page stopping (another page on top, Home, another app, the screen off) pauses the recording, and so
    // does the page leaving; the ViewModel releases the player when it's cleared.
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    DisposableEffect(lifecycle, viewModel) {
        val observer = pauseOnStop(viewModel::onAction)
        lifecycle.addObserver(observer)
        onDispose {
            lifecycle.removeObserver(observer)
            viewModel.onAction(DhikrDetailAction.Pause)
        }
    }
    val back by rememberUpdatedState(onBack)
    LaunchedEffect(state.isDeleted) { if (state.isDeleted) back() }
    DhikrDetailScreen(
        state = state,
        onAction = viewModel::onAction,
        onEdit = { onNavigate(LibraryDestination.Editor(dhikrId)) },
        onBack = onBack,
        modifier = modifier,
    )
}

/**
 * A top bar with Back, the title and, for the user's own dhikr, Edit; a conflict banner when the dhikr or its
 * tags changed on another device; the Arabic card (with the player bar when there's a recording), then the
 * transliteration, translation, tags with "Manage tags", virtues and sources, each under its `sectionTitle`. A
 * section with nothing to show is left out (components.md, "Dhikr detail screen"). A custom dhikr ends with
 * Delete.
 */
@Composable
internal fun DhikrDetailScreen(
    state: DhikrDetailUiState,
    onAction: (DhikrDetailAction) -> Unit,
    onEdit: () -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val language = currentContentLanguage()
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(AwradTheme.colors.background)
            .statusBarsPadding(),
    ) {
        AwradTopBar(
            title = state.dhikr?.title?.localized(language),
            onBack = onBack,
            actions = {
                if (state.custom != null) {
                    AwradTextButton(text = stringResource(R.string.library_edit), onClick = onEdit)
                }
            },
        )
        when {
            state.dhikr != null -> DhikrDetailContent(state = state, language = language, onAction = onAction)
            !state.isLoading -> MissingContent()
        }
    }
    state.sheet?.let { sheet ->
        DhikrTagsSheet(
            sheet = sheet,
            tags = state.allTags,
            selected = state.tags.map { it.id }.toSet(),
            onAction = { onAction(DhikrDetailAction.Tags(it)) },
        )
    }
    if (state.isDeleteConfirmOpen) {
        DeleteDhikrDialog(
            onConfirm = { onAction(DhikrDetailAction.ConfirmDelete) },
            onDismiss = { onAction(DhikrDetailAction.CancelDelete) },
        )
    }
}

@Composable
private fun DhikrDetailContent(
    state: DhikrDetailUiState,
    language: ContentLanguage,
    onAction: (DhikrDetailAction) -> Unit,
    modifier: Modifier = Modifier,
) {
    val dhikr = checkNotNull(state.dhikr)
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
        if (state.conflict != null) {
            ConflictBanner(
                onKeepMine = { onAction(DhikrDetailAction.Resolve(ConflictChoice.KEEP_MINE)) },
                onUseTheirs = { onAction(DhikrDetailAction.Resolve(ConflictChoice.USE_THEIRS)) },
            )
        }
        ArabicCard(
            dhikr = dhikr,
            language = language,
            hasRecording = state.hasRecording,
            playback = state.playback,
            onTogglePlayback = { onAction(DhikrDetailAction.TogglePlayback) },
        )
        TextSections(state = state, language = language)
        TagsSection(
            state = state,
            language = language,
            onManage = { onAction(DhikrDetailAction.Tags(TagSheetAction.Open)) },
        )
        if (dhikr.virtues.isNotEmpty()) Virtues(virtues = dhikr.virtues, language = language)
        dhikr.sources.takeIf { it.isNotEmpty() }?.let { Sources(references = it) }
        if (state.custom != null) {
            AwradTextButton(
                text = stringResource(R.string.library_delete_dhikr),
                onClick = { onAction(DhikrDetailAction.AskDelete) },
                isDestructive = true,
            )
        }
    }
}

/**
 * "Transliteration" (none in Arabic) and "Translation", left out for a name of Allah (its title is the
 * transliteration, its meaning is in the card); a custom dhikr may have neither.
 */
@Composable
private fun TextSections(state: DhikrDetailUiState, language: ContentLanguage, modifier: Modifier = Modifier) {
    val dhikr = checkNotNull(state.dhikr)
    val custom = state.custom
    val (transliteration, translation) = if (custom != null) {
        custom.textIn(language).let { it.transliteration to it.translation }
    } else {
        dhikr.textIn(language).let { it.transliteration to it.translation }
    }
    val isName = dhikr.kind == DhikrKind.NAME_OF_ALLAH
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.sectionGap)) {
        transliteration?.takeUnless { isName || it.isBlank() }?.let {
            TextSection(title = stringResource(R.string.library_transliteration), text = it)
        }
        translation?.takeUnless { isName }?.let {
            TextSection(title = stringResource(R.string.library_translation), text = it)
        }
    }
}

/** A `sectionTitle`, with an optional [action] at the end, then its [content]. */
@Composable
private fun DetailSection(
    title: String,
    modifier: Modifier = Modifier,
    action: (@Composable () -> Unit)? = null,
    content: @Composable () -> Unit,
) {
    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.sm)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            AwradSectionTitle(text = title, modifier = Modifier.weight(1f))
            action?.invoke()
        }
        content()
    }
}

@Composable
private fun TextSection(title: String, text: String, modifier: Modifier = Modifier) {
    DetailSection(title = title, modifier = modifier) {
        Text(text = text, style = AwradTheme.type.body, color = AwradTheme.colors.onSurface)
    }
}

/** "Tags": the catalog's topic tags, then the user's own, and "Manage tags" for every dhikr. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun TagsSection(
    state: DhikrDetailUiState,
    language: ContentLanguage,
    onManage: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val catalogTags = state.dhikr?.tags.orEmpty()
    DetailSection(
        title = stringResource(R.string.library_tags),
        modifier = modifier,
        action = { AwradTextButton(text = stringResource(R.string.library_manage_tags), onClick = onManage) },
    ) {
        if (catalogTags.isEmpty() && state.tags.isEmpty()) {
            Text(
                text = stringResource(R.string.library_no_tags),
                style = AwradTheme.type.bodySmall,
                color = AwradTheme.colors.onSurfaceVariant,
            )
        } else {
            FlowRow(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(AwradTheme.spacing.sm),
                verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.sm),
            ) {
                catalogTags.forEach { AwradChip(text = it.title.localized(language)) }
                state.tags.forEach { AwradChip(text = it.name) }
            }
        }
    }
}

/** "Virtues", then a card per virtue: its text in `body`, and under it each reference it cites. */
@Composable
private fun Virtues(virtues: List<Virtue>, language: ContentLanguage, modifier: Modifier = Modifier) {
    DetailSection(title = stringResource(R.string.library_virtues), modifier = modifier) {
        virtues.forEach { virtue ->
            AwradCard(spacing = AwradTheme.spacing.sm) {
                Text(text = virtue.text.localized(language), style = AwradTheme.type.body)
                virtue.references.forEach { reference -> ReferenceLine(label = referenceLabel(reference)) }
            }
        }
    }
}

/**
 * "Sources" (slice 3b), after Virtues: the references not already shown, one per line, in the dhikr's order
 * ([app.awrad.core.domain.dhikr.Dhikr.sources]). A custom dhikr, which has no virtues, lists all of its own.
 */
@Composable
private fun Sources(references: List<Reference>, modifier: Modifier = Modifier) {
    DetailSection(title = stringResource(R.string.library_sources), modifier = modifier) {
        references.forEach { ReferenceLine(label = referenceLabel(it)) }
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
