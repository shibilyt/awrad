package app.awrad.feature.library

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.hilt.navigation.compose.hiltViewModel
import app.awrad.core.designsystem.component.AwradButton
import app.awrad.core.designsystem.component.AwradTextButton
import app.awrad.core.designsystem.component.AwradTopBar
import app.awrad.core.designsystem.theme.AwradTheme

/** Stateful editor: the ViewModel, the system file picker for recordings, and closing once saved or deleted. */
@Composable
internal fun CustomDhikrEditorRoute(
    dhikrId: String?,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: CustomDhikrEditorViewModel =
        hiltViewModel<CustomDhikrEditorViewModel, CustomDhikrEditorViewModel.Factory>(
            key = dhikrId ?: NEW_DHIKR,
            creationCallback = { it.create(dhikrId) },
        ),
) {
    val state by viewModel.state
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        uri?.let { viewModel.onAction(EditorAction.ImportAudio(it.toString())) }
    }
    val close by rememberUpdatedState(onClose)
    LaunchedEffect(state.isDone) { if (state.isDone) close() }
    CustomDhikrEditorScreen(
        state = state,
        onAction = viewModel::onAction,
        onPickAudio = { picker.launch(AUDIO_TYPES) },
        onBack = onClose,
        modifier = modifier,
    )
}

/**
 * The custom dhikr editor: a top bar with Back, the title ("New dhikr" or "Edit dhikr") and Save; then the kind,
 * the Arabic text (required), the title, transliteration and translation of one language at a time (pills switch
 * between English, Arabic and Malayalam), the Qur'an reference and other references, the recording, and tags.
 * Save at the end, and Delete (with a confirmation) for a dhikr that exists. A save that fails scrolls to the first
 * problem and moves focus there, so it's seen (and read out) even when it's above what's on screen.
 */
@Composable
internal fun CustomDhikrEditorScreen(
    state: EditorUiState,
    onAction: (EditorAction) -> Unit,
    onPickAudio: () -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val spacing = AwradTheme.spacing
    val navigationBar = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val targets = rememberProblemTargets(state)
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(AwradTheme.colors.background)
            .statusBarsPadding()
            .imePadding(),
    ) {
        AwradTopBar(
            title = stringResource(if (state.isNew) R.string.editor_title_new else R.string.editor_title_edit),
            onBack = onBack,
            actions = {
                AwradTextButton(
                    text = stringResource(R.string.editor_save),
                    onClick = { onAction(EditorAction.Save) },
                    enabled = !state.isLoading && !state.isSaving,
                )
            },
        )
        if (state.isLoading) return@Column
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = spacing.pageMargin)
                .padding(top = spacing.sm, bottom = spacing.sectionGap + navigationBar),
            verticalArrangement = Arrangement.spacedBy(spacing.sectionGap),
        ) {
            ProblemsLine(problems = state.problems, modifier = Modifier.problemSpot(targets, ProblemSpot.SUMMARY))
            KindSection(kind = state.kind, onAction = onAction)
            ArabicSection(state = state, onAction = onAction, targets = targets)
            TextsSection(state = state, onAction = onAction, targets = targets)
            ReferencesSection(state = state, onAction = onAction, targets = targets)
            AudioSection(state = state, onAction = onAction, onPickAudio = onPickAudio)
            EditorTagsSection(state = state, onAction = onAction)
            AwradButton(
                text = stringResource(R.string.editor_save),
                onClick = { onAction(EditorAction.Save) },
                isLoading = state.isSaving,
            )
            if (!state.isNew) {
                AwradTextButton(
                    text = stringResource(R.string.library_delete_dhikr),
                    onClick = { onAction(EditorAction.AskDelete) },
                    isDestructive = true,
                )
            }
        }
    }
    if (state.isDeleteConfirmOpen) {
        DeleteDhikrDialog(
            onConfirm = { onAction(EditorAction.ConfirmDelete) },
            onDismiss = { onAction(EditorAction.CancelDelete) },
        )
    }
}

/** The navigation key of the editor for a new dhikr. */
private const val NEW_DHIKR = "new"

/** MP3 and M4A/AAC, as slice 3c will upload (contracts: 10 MB, MP3 and M4A/AAC). */
private val AUDIO_TYPES = arrayOf("audio/mpeg", "audio/mp4", "audio/x-m4a", "audio/aac")
