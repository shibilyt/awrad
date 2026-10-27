package app.awrad.core.designsystem.component

import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonColors
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import app.awrad.core.designsystem.motion.AwradPressTarget
import app.awrad.core.designsystem.motion.pressFeedback
import app.awrad.core.designsystem.theme.AwradTheme

/*
 * Buttons by role, all filled or text-only: the design has no outlines. Material's outlined and text buttons
 * draw their label in `primary`, which is too dark to read on a dark background, and a border; these use
 * `onSurface`, `accent` and `error` instead. Every one shrinks a little while pressed (`press`). The full-width
 * ones are `control` high. Disabled, they keep their colours at `states.disabled.opacity`.
 */

/** The one full-width call to action per screen: a `primary` fill. */
@Composable
public fun AwradPrimaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    trailingIcon: ImageVector? = null,
) {
    val colors = AwradTheme.colors
    val interactionSource = remember { MutableInteractionSource() }
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier
            .pressFeedback(interactionSource, AwradPressTarget.Button)
            .disabledOpacity(enabled)
            .fillMaxWidth()
            .height(AwradTheme.sizes.control),
        shape = AwradTheme.shapes.button,
        colors = filledColors(container = colors.primary, content = colors.onPrimary),
        interactionSource = interactionSource,
    ) {
        Text(text = text, style = AwradTheme.type.button)
        if (trailingIcon != null) {
            Spacer(modifier = Modifier.width(AwradTheme.spacing.inlineGap))
            Icon(
                imageVector = trailingIcon,
                contentDescription = null,
                modifier = Modifier.size(AwradTheme.sizes.iconSmall),
            )
        }
    }
}

/**
 * A full-width secondary action, the same size as the primary one: filled like a field ([AwradTheme.fill],
 * `surface` on a `background`, `background` inside an `AwradCard`), `onSurface` text, no border.
 */
@Composable
public fun AwradSecondaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    val colors = AwradTheme.colors
    val fill = AwradTheme.fill
    val interactionSource = remember { MutableInteractionSource() }
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier
            .pressFeedback(interactionSource, AwradPressTarget.Button)
            .disabledOpacity(enabled)
            .fillMaxWidth()
            .height(AwradTheme.sizes.control),
        shape = AwradTheme.shapes.button,
        colors = filledColors(container = fill, content = colors.onSurface),
        interactionSource = interactionSource,
    ) {
        Text(text = text, style = AwradTheme.type.button)
    }
}

/** A full-width action that can't be taken back, such as deleting the account: an `error` fill. */
@Composable
public fun AwradDestructiveButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    val colors = AwradTheme.colors
    val interactionSource = remember { MutableInteractionSource() }
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier
            .pressFeedback(interactionSource, AwradPressTarget.Button)
            .disabledOpacity(enabled)
            .fillMaxWidth()
            .height(AwradTheme.sizes.control),
        shape = AwradTheme.shapes.button,
        colors = filledColors(container = colors.error, content = colors.onError),
        interactionSource = interactionSource,
    ) {
        Text(text = text, style = AwradTheme.type.button)
    }
}

/**
 * A text-only action, such as a link to another page or a dialog's buttons: `accent` text, or `error` when
 * [isDestructive]. [isEmphasized] sets it in semibold, for a dialog's confirm button.
 */
@Composable
public fun AwradTextButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    isDestructive: Boolean = false,
    isEmphasized: Boolean = false,
) {
    val colors = AwradTheme.colors
    val content = if (isDestructive) colors.error else colors.accent
    val interactionSource = remember { MutableInteractionSource() }
    TextButton(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier
            .pressFeedback(interactionSource, AwradPressTarget.Button)
            .disabledOpacity(enabled),
        shape = AwradTheme.shapes.button,
        colors = ButtonDefaults.textButtonColors(contentColor = content, disabledContentColor = content),
        interactionSource = interactionSource,
    ) {
        Text(
            text = text,
            style = AwradTheme.type.label,
            fontWeight = if (isEmphasized) AwradTheme.type.button.fontWeight else null,
        )
    }
}

/** A filled button's colours, the same when disabled (`disabledOpacity` dims the whole button instead). */
@Composable
private fun filledColors(container: Color, content: Color): ButtonColors = ButtonDefaults.buttonColors(
    containerColor = container,
    contentColor = content,
    disabledContainerColor = container,
    disabledContentColor = content,
)
