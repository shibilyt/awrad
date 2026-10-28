package app.awrad.feature.library

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.hilt.navigation.compose.hiltViewModel
import app.awrad.core.designsystem.component.AwradButtonVariant
import app.awrad.core.designsystem.component.AwradCard
import app.awrad.core.designsystem.component.AwradCardSize
import app.awrad.core.designsystem.component.AwradDialog
import app.awrad.core.designsystem.component.AwradIconButton
import app.awrad.core.designsystem.component.AwradRowButton
import app.awrad.core.designsystem.component.AwradTextButton
import app.awrad.core.designsystem.component.AwradTextField
import app.awrad.core.designsystem.component.AwradTopBar
import app.awrad.core.designsystem.icon.AwradIcons
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.core.domain.personal.UserTag

@Composable
internal fun ManageTagsRoute(
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: ManageTagsViewModel = hiltViewModel(),
) {
    val state by viewModel.state
    ManageTagsScreen(state = state, onAction = viewModel::onAction, onBack = onBack, modifier = modifier)
}

/**
 * "Manage tags": a top bar with Back, a field to make a tag, then every tag as a row with Rename and Delete.
 * Renaming happens in the row; deleting asks first, since the tag leaves every dhikr that has it.
 */
@Composable
internal fun ManageTagsScreen(
    state: ManageTagsUiState,
    onAction: (ManageTagsAction) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val spacing = AwradTheme.spacing
    val navigationBar = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(AwradTheme.colors.background)
            .statusBarsPadding()
            .imePadding(),
    ) {
        AwradTopBar(title = stringResource(R.string.library_manage_tags), onBack = onBack)
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(
                start = spacing.pageMargin,
                end = spacing.pageMargin,
                top = spacing.sm,
                bottom = spacing.sectionGap + navigationBar,
            ),
            verticalArrangement = Arrangement.spacedBy(spacing.rowGap),
        ) {
            item(key = "new") {
                NewTagField(
                    name = state.newName,
                    error = state.createError?.let { tagErrorText(it) },
                    onNameChange = { onAction(ManageTagsAction.NewNameChanged(it)) },
                    onCreate = { onAction(ManageTagsAction.Create) },
                )
            }
            if (!state.isLoading && state.tags.isEmpty()) {
                item(key = "empty") {
                    Text(
                        text = stringResource(R.string.library_tags_empty),
                        style = AwradTheme.type.bodySmall,
                        color = AwradTheme.colors.onSurfaceVariant,
                    )
                }
            }
            items(state.tags, key = { it.id.value }) { tag ->
                val renaming = state.renaming?.takeIf { it.tagId == tag.id }
                if (renaming != null) {
                    RenameRow(renaming = renaming, onAction = onAction)
                } else {
                    TagRow(tag = tag, onAction = onAction)
                }
            }
        }
    }
    state.deleting?.let { tag -> DeleteTagDialog(tag = tag, onAction = onAction) }
}

/** "Delete the tag?": it leaves every dhikr that has it. */
@Composable
private fun DeleteTagDialog(tag: UserTag, onAction: (ManageTagsAction) -> Unit, modifier: Modifier = Modifier) {
    AwradDialog(
        onDismissRequest = { onAction(ManageTagsAction.CancelDelete) },
        title = stringResource(R.string.tags_delete_title, tag.name),
        text = stringResource(R.string.tags_delete_body),
        modifier = modifier,
        confirmButton = {
            AwradRowButton(
                text = stringResource(R.string.tags_delete_confirm),
                onClick = { onAction(ManageTagsAction.ConfirmDelete) },
                variant = AwradButtonVariant.Error,
            )
        },
        dismissButton = {
            AwradTextButton(
                text = stringResource(R.string.library_cancel),
                onClick = { onAction(ManageTagsAction.CancelDelete) },
            )
        },
    )
}

@Composable
private fun TagRow(tag: UserTag, onAction: (ManageTagsAction) -> Unit, modifier: Modifier = Modifier) {
    AwradCard(modifier = modifier, size = AwradCardSize.Tile) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = tag.name,
                modifier = Modifier.weight(1f),
                style = AwradTheme.type.rowTitle,
                color = AwradTheme.colors.onSurface,
            )
            AwradTextButton(
                text = stringResource(R.string.tags_rename),
                onClick = { onAction(ManageTagsAction.StartRename(tag.id)) },
            )
            AwradIconButton(
                icon = AwradIcons.Delete,
                contentDescription = stringResource(R.string.tags_delete, tag.name),
                onClick = { onAction(ManageTagsAction.AskDelete(tag.id)) },
                tint = AwradTheme.colors.error,
            )
        }
    }
}

@Composable
private fun RenameRow(renaming: Renaming, onAction: (ManageTagsAction) -> Unit, modifier: Modifier = Modifier) {
    AwradCard(modifier = modifier, size = AwradCardSize.Tile) {
        AwradTextField(
            value = renaming.name,
            onValueChange = { onAction(ManageTagsAction.RenameChanged(it)) },
            label = stringResource(R.string.tags_rename),
            error = renaming.error?.let { tagErrorText(it) },
        )
        Row(horizontalArrangement = Arrangement.spacedBy(AwradTheme.spacing.sm)) {
            AwradRowButton(
                text = stringResource(R.string.editor_save),
                onClick = { onAction(ManageTagsAction.ConfirmRename) },
                variant = AwradButtonVariant.Main,
            )
            AwradTextButton(
                text = stringResource(R.string.library_cancel),
                onClick = { onAction(ManageTagsAction.CancelRename) },
            )
        }
    }
}
