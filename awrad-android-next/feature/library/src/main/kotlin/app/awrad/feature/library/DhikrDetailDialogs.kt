package app.awrad.feature.library

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.key
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import app.awrad.core.designsystem.component.AwradBottomSheet
import app.awrad.core.designsystem.component.AwradButtonVariant
import app.awrad.core.designsystem.component.AwradDialog
import app.awrad.core.designsystem.component.AwradIconButton
import app.awrad.core.designsystem.component.AwradOptionRow
import app.awrad.core.designsystem.component.AwradRowButton
import app.awrad.core.designsystem.component.AwradSelectionMode
import app.awrad.core.designsystem.component.AwradTextButton
import app.awrad.core.designsystem.component.AwradTextField
import app.awrad.core.designsystem.icon.AwradIcons
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.personal.UserTag

/**
 * "Manage tags" for one dhikr, a bottom sheet: each tag as a checkbox row (on or off for this dhikr), then a field
 * to make a new tag, which this dhikr gets at once. A name the shared rules refuse, a tag that exists, or too many
 * tags shows under the field.
 */
@Composable
internal fun DhikrTagsSheet(
    sheet: TagSheetState,
    tags: List<UserTag>,
    selected: Set<AwradId>,
    onAction: (TagSheetAction) -> Unit,
    modifier: Modifier = Modifier,
) {
    val spacing = AwradTheme.spacing
    AwradBottomSheet(onDismissRequest = { onAction(TagSheetAction.Close) }, modifier = modifier) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = spacing.pageMargin)
                .padding(bottom = spacing.sectionGap),
            verticalArrangement = Arrangement.spacedBy(spacing.rowGap),
        ) {
            Text(
                text = stringResource(R.string.library_manage_tags),
                modifier = Modifier.semantics { heading() },
                style = AwradTheme.type.title,
                color = AwradTheme.colors.onSurface,
            )
            if (tags.isEmpty()) {
                Text(
                    text = stringResource(R.string.library_tags_empty),
                    style = AwradTheme.type.bodySmall,
                    color = AwradTheme.colors.onSurfaceVariant,
                )
            }
            tags.forEach { tag ->
                key(tag.id.value) {
                    AwradOptionRow(
                        label = tag.name,
                        selected = tag.id in selected,
                        onClick = { onAction(TagSheetAction.Toggle(tag.id)) },
                        mode = AwradSelectionMode.Multiple,
                    )
                }
            }
            NewTagField(
                name = sheet.newName,
                error = sheet.error?.let { tagErrorText(it) },
                onNameChange = { onAction(TagSheetAction.NameChanged(it)) },
                onCreate = { onAction(TagSheetAction.Create) },
            )
        }
    }
}

/** A field for a new tag's name, with an Add button at its end (and the keyboard's Done). */
@Composable
internal fun NewTagField(
    name: String,
    error: String?,
    onNameChange: (String) -> Unit,
    onCreate: () -> Unit,
    modifier: Modifier = Modifier,
) {
    AwradTextField(
        value = name,
        onValueChange = onNameChange,
        label = stringResource(R.string.library_new_tag),
        modifier = modifier,
        error = error,
        placeholder = stringResource(R.string.library_new_tag_placeholder),
        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
        keyboardActions = KeyboardActions(onDone = { if (name.isNotBlank()) onCreate() }),
        trailingIcon = {
            AwradIconButton(
                icon = AwradIcons.Add,
                contentDescription = stringResource(R.string.library_add_tag),
                onClick = onCreate,
                enabled = name.isNotBlank(),
                tint = AwradTheme.colors.accent,
            )
        },
    )
}

/** "Delete this dhikr?", with what goes with it; a destructive confirmation. */
@Composable
internal fun DeleteDhikrDialog(onConfirm: () -> Unit, onDismiss: () -> Unit, modifier: Modifier = Modifier) {
    AwradDialog(
        onDismissRequest = onDismiss,
        title = stringResource(R.string.library_delete_title),
        text = stringResource(R.string.library_delete_body),
        modifier = modifier,
        confirmButton = {
            AwradRowButton(
                text = stringResource(R.string.library_delete_confirm),
                onClick = onConfirm,
                variant = AwradButtonVariant.Error,
            )
        },
        dismissButton = { AwradTextButton(text = stringResource(R.string.library_cancel), onClick = onDismiss) },
    )
}
