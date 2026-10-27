package app.awrad.core.designsystem.component

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.selection.LocalTextSelectionColors
import androidx.compose.foundation.text.selection.TextSelectionColors
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import app.awrad.core.designsystem.R
import app.awrad.core.designsystem.icon.AwradIcons
import app.awrad.core.designsystem.theme.AwradTheme

/** The selection highlight, as in [AwradTextField]: the tokens have no selection colour, so `accent` at 40%. */
private const val SEARCH_SELECTION_ALPHA = 0.4f

/**
 * A search box: the field of [AwradTextField] (`control` tall, `field` shape, the container's fill, `input` text,
 * `accent` cursor) without the label above it. The `search` icon leads, in `onSurfaceVariant`; [placeholder]
 * shows until something is typed and is the field's label for screen readers. With text in it, a Close icon
 * button clears it. The keyboard's action is Search, which hides the keyboard.
 */
@Composable
public fun AwradSearchField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    val colors = AwradTheme.colors
    val focus = LocalFocusManager.current
    val selectionColors = TextSelectionColors(
        handleColor = colors.accent,
        backgroundColor = colors.accent.copy(alpha = SEARCH_SELECTION_ALPHA),
    )
    CompositionLocalProvider(LocalTextSelectionColors provides selectionColors) {
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = modifier
                .disabledOpacity(enabled)
                .fillMaxWidth()
                .semantics { contentDescription = placeholder },
            enabled = enabled,
            textStyle = AwradTheme.type.input.copy(color = colors.onSurface),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
            keyboardActions = KeyboardActions(onSearch = { focus.clearFocus() }),
            singleLine = true,
            cursorBrush = SolidColor(colors.accent),
            decorationBox = { innerTextField ->
                SearchDecoration(
                    placeholder = placeholder.takeIf { value.isEmpty() },
                    onClear = { onValueChange("") }.takeIf { value.isNotEmpty() },
                    innerTextField = innerTextField,
                )
            },
        )
    }
}

@Composable
private fun SearchDecoration(
    placeholder: String?,
    onClear: (() -> Unit)?,
    innerTextField: @Composable () -> Unit,
) {
    val colors = AwradTheme.colors
    val spacing = AwradTheme.spacing
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(AwradTheme.sizes.control)
            .background(color = AwradTheme.fill, shape = AwradTheme.shapes.field)
            // A clear button's own 48 target pads its glyph, which then lines up with `lg`.
            .padding(start = spacing.lg, end = if (onClear == null) spacing.lg else spacing.xs),
        horizontalArrangement = Arrangement.spacedBy(spacing.inlineGap),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = AwradIcons.Search,
            contentDescription = null,
            modifier = Modifier.size(AwradTheme.sizes.icon),
            tint = colors.onSurfaceVariant,
        )
        Box(modifier = Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
            if (placeholder != null) {
                Text(
                    text = placeholder,
                    // It's already the field's description; read once.
                    modifier = Modifier.clearAndSetSemantics {},
                    style = AwradTheme.type.input,
                    color = colors.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            innerTextField()
        }
        if (onClear != null) {
            AwradIconButton(
                icon = AwradIcons.Close,
                contentDescription = stringResource(R.string.awrad_action_clear_search),
                onClick = onClear,
                tint = colors.onSurfaceVariant,
            )
        }
    }
}
