package app.awrad.core.designsystem.component

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.selection.LocalTextSelectionColors
import androidx.compose.foundation.text.selection.TextSelectionColors
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextFieldColors
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.VisualTransformation
import app.awrad.core.designsystem.theme.AwradTheme

/** The selection highlight behind selected text: the tokens have no selection colour, so `accent` at 40%. */
private const val SELECTION_ALPHA = 0.4f

/**
 * A full-width, single-line text field, `control` high, filled and without a line: [AwradTheme.fill] (`surface`
 * on a `background`, `background` inside an `AwradCard`). The typed text is the `input` style. Focus shows as the
 * `accent` cursor only. The label is `onSurfaceVariant`. With [isError] it gets an `error` border
 * (`strokes.fieldError`), and [supportingText] (the error) turns `error`; otherwise [supportingText] is a hint
 * below the field. Disabled, it keeps its colours at `states.disabled.opacity`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
public fun AwradTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    isError: Boolean = false,
    supportingText: String? = null,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    visualTransformation: VisualTransformation = VisualTransformation.None,
    trailingIcon: (@Composable () -> Unit)? = null,
) {
    val colors = AwradTheme.colors
    val fill = AwradTheme.fill
    val fieldColors = awradTextFieldColors(fill)
    val shape = AwradTheme.shapes.field
    val interactionSource = remember { MutableInteractionSource() }
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
                .defaultMinSize(minWidth = TextFieldDefaults.MinWidth, minHeight = AwradTheme.sizes.control)
                .semantics { if (isError) error(supportingText.orEmpty()) },
            enabled = enabled,
            textStyle = AwradTheme.type.input.copy(color = colors.onSurface),
            keyboardOptions = keyboardOptions,
            singleLine = true,
            visualTransformation = visualTransformation,
            interactionSource = interactionSource,
            cursorBrush = SolidColor(colors.accent),
            decorationBox = { innerTextField ->
                TextFieldDefaults.DecorationBox(
                    value = value,
                    innerTextField = innerTextField,
                    enabled = enabled,
                    singleLine = true,
                    visualTransformation = visualTransformation,
                    interactionSource = interactionSource,
                    isError = isError,
                    label = { Text(text = label) },
                    trailingIcon = trailingIcon,
                    supportingText = supportingText?.let { { Text(text = it) } },
                    shape = shape,
                    colors = fieldColors,
                    // The fill covers the field only, not the supporting text below it.
                    container = { FieldContainer(fill = fill, shape = shape, isError = isError) },
                )
            },
        )
    }
}

/** The field's [fill]; with [isError], an `error` border `strokes.fieldError` wide. */
@Composable
private fun FieldContainer(fill: Color, shape: Shape, isError: Boolean) {
    val container = Modifier
        .fillMaxSize()
        .background(color = fill, shape = shape)
    Box(
        modifier = if (isError) {
            container.border(width = AwradTheme.strokes.fieldError, color = AwradTheme.colors.error, shape = shape)
        } else {
            container
        },
    )
}

/**
 * Label, icons and hint in `onSurfaceVariant` (the hint in `error` with an error); no indicator line. Disabled
 * keeps the same colours: `disabledOpacity` dims the whole field instead.
 */
@Composable
private fun awradTextFieldColors(fill: Color): TextFieldColors {
    val colors = AwradTheme.colors
    val variant = colors.onSurfaceVariant
    return TextFieldDefaults.colors(
        focusedContainerColor = fill,
        unfocusedContainerColor = fill,
        disabledContainerColor = fill,
        errorContainerColor = fill,
        cursorColor = colors.accent,
        errorCursorColor = colors.accent,
        focusedIndicatorColor = Color.Transparent,
        unfocusedIndicatorColor = Color.Transparent,
        disabledIndicatorColor = Color.Transparent,
        errorIndicatorColor = Color.Transparent,
        focusedLabelColor = variant,
        unfocusedLabelColor = variant,
        disabledLabelColor = variant,
        errorLabelColor = variant,
        focusedPlaceholderColor = variant,
        unfocusedPlaceholderColor = variant,
        disabledPlaceholderColor = variant,
        errorPlaceholderColor = variant,
        focusedTrailingIconColor = variant,
        unfocusedTrailingIconColor = variant,
        disabledTrailingIconColor = variant,
        errorTrailingIconColor = variant,
        focusedSupportingTextColor = variant,
        unfocusedSupportingTextColor = variant,
        disabledSupportingTextColor = variant,
        errorSupportingTextColor = colors.error,
    )
}

/** A thin bar (`ringStroke` high) while work of unknown length runs, in `progress` on an `outline` track. */
@Composable
public fun AwradLinearProgress(modifier: Modifier = Modifier) {
    LinearProgressIndicator(
        modifier = modifier
            .fillMaxWidth()
            .height(AwradTheme.sizes.ringStroke),
        color = AwradTheme.colors.progress,
        trackColor = AwradTheme.colors.outline,
    )
}

/** A spinner while a page loads, in `progress`. */
@Composable
public fun AwradCircularProgress(modifier: Modifier = Modifier) {
    CircularProgressIndicator(modifier = modifier, color = AwradTheme.colors.progress)
}
