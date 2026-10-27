package app.awrad.core.designsystem.component

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.selection.LocalTextSelectionColors
import androidx.compose.foundation.text.selection.TextSelectionColors
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextOverflow
import app.awrad.core.designsystem.theme.AwradTheme

/** The selection highlight behind selected text: the tokens have no selection colour, so `accent` at 40%. */
private const val SELECTION_ALPHA = 0.4f

/**
 * A single-line text field (components.md, "Text field"): the [label] above it (`label` style, `onSurface`, `xs`
 * gap; not a floating label), then the field itself, exactly `control` (56) tall, `field` shape, filled with
 * [AwradTheme.fill] (`surface` on a `background`, `background` on a `surface`) and padded `lg`. The typed text is
 * the `input` style; [placeholder] is `onSurfaceVariant`. Focus shows as the `accent` cursor only.
 *
 * [error] is the message for an error: with one, the field gets an `error` border (`strokes.fieldError`) and
 * the message shows below in `caption`, `error`. There's no error flag, so the border can't appear without a
 * message; a blank message counts as none. Otherwise [supportingText] shows below in `onSurfaceVariant`.
 * Disabled, it keeps its colours at `states.disabled.opacity`. The label, value and message are one node for
 * screen readers.
 */
@Composable
public fun AwradTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    error: String? = null,
    supportingText: String? = null,
    placeholder: String? = null,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
    visualTransformation: VisualTransformation = VisualTransformation.None,
    trailingIcon: (@Composable () -> Unit)? = null,
) {
    val colors = AwradTheme.colors
    val message = fieldMessage(error = error, supportingText = supportingText)
    val selectionColors = TextSelectionColors(
        handleColor = colors.accent,
        backgroundColor = colors.accent.copy(alpha = SELECTION_ALPHA),
    )
    CompositionLocalProvider(LocalTextSelectionColors provides selectionColors) {
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = modifier
                .disabledOpacity(enabled)
                .fillMaxWidth()
                .semantics { if (message is FieldMessage.Error) error(message.text) },
            enabled = enabled,
            textStyle = AwradTheme.type.input.copy(color = colors.onSurface),
            keyboardOptions = keyboardOptions,
            keyboardActions = keyboardActions,
            singleLine = true,
            visualTransformation = visualTransformation,
            cursorBrush = SolidColor(colors.accent),
            decorationBox = { innerTextField ->
                FieldDecoration(
                    label = label,
                    isEmpty = value.isEmpty(),
                    placeholder = placeholder,
                    message = message,
                    trailingIcon = trailingIcon,
                    innerTextField = innerTextField,
                )
            },
        )
    }
}

/** Label, field and message, all inside the text field's own node. */
@Composable
private fun FieldDecoration(
    label: String,
    isEmpty: Boolean,
    placeholder: String?,
    message: FieldMessage?,
    trailingIcon: (@Composable () -> Unit)?,
    innerTextField: @Composable () -> Unit,
) {
    val colors = AwradTheme.colors
    val shape = AwradTheme.shapes.field
    val isError = message is FieldMessage.Error
    Column(verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.xs)) {
        Text(text = label, style = AwradTheme.type.label, color = colors.onSurface)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(AwradTheme.sizes.control)
                .background(color = AwradTheme.fill, shape = shape)
                .then(
                    if (isError) {
                        Modifier.border(width = AwradTheme.strokes.fieldError, color = colors.error, shape = shape)
                    } else {
                        Modifier
                    },
                )
                // A trailing icon button's own 48 target pads its glyph, which then lines up with `lg`.
                .padding(
                    start = AwradTheme.spacing.lg,
                    end = if (trailingIcon == null) AwradTheme.spacing.lg else AwradTheme.spacing.xs,
                ),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(modifier = Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
                if (isEmpty && placeholder != null) {
                    Text(
                        text = placeholder,
                        style = AwradTheme.type.input,
                        color = colors.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                innerTextField()
            }
            if (trailingIcon != null) {
                CompositionLocalProvider(LocalContentColor provides colors.onSurfaceVariant, content = trailingIcon)
            }
        }
        if (message != null) {
            Text(
                text = message.text,
                style = AwradTheme.type.caption,
                color = if (isError) colors.error else colors.onSurfaceVariant,
            )
        }
    }
}
