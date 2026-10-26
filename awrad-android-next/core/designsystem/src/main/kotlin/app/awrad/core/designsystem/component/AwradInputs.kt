package app.awrad.core.designsystem.component

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.selection.TextSelectionColors
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.VisualTransformation
import app.awrad.core.designsystem.theme.AwradTheme

private const val SELECTION_ALPHA = 0.4f

/**
 * A full-width, single-line text field. Its border is `outlineStrong` (`accent` while focused, `error` with
 * [isError]); Material's would be the decorative `outline`, and its focus colour `primary`, which is too dark
 * to see on a dark background. [supportingText] is the hint or the error below it.
 */
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
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier.fillMaxWidth(),
        enabled = enabled,
        label = { Text(text = label) },
        trailingIcon = trailingIcon,
        supportingText = supportingText?.let { { Text(text = it) } },
        isError = isError,
        visualTransformation = visualTransformation,
        keyboardOptions = keyboardOptions,
        singleLine = true,
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = colors.accent,
            unfocusedBorderColor = colors.outlineStrong,
            focusedLabelColor = colors.accent,
            cursorColor = colors.accent,
            selectionColors = TextSelectionColors(
                handleColor = colors.accent,
                backgroundColor = colors.accent.copy(alpha = SELECTION_ALPHA),
            ),
        ),
    )
}

/** A thin bar while work of unknown length runs, in `progress` on an `outline` track. */
@Composable
public fun AwradLinearProgress(modifier: Modifier = Modifier) {
    LinearProgressIndicator(
        modifier = modifier.fillMaxWidth(),
        color = AwradTheme.colors.progress,
        trackColor = AwradTheme.colors.outline,
    )
}

/** A spinner while a page loads, in `progress`. */
@Composable
public fun AwradCircularProgress(modifier: Modifier = Modifier) {
    CircularProgressIndicator(modifier = modifier, color = AwradTheme.colors.progress)
}
