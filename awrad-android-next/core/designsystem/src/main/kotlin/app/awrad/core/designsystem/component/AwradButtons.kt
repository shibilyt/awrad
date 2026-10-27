package app.awrad.core.designsystem.component

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.ripple
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import app.awrad.core.designsystem.R
import app.awrad.core.designsystem.motion.AwradPressTarget
import app.awrad.core.designsystem.motion.pressFeedback
import app.awrad.core.designsystem.theme.AwradTheme

/*
 * Buttons (components.md, "Buttons"): filled or text-only, never outlined. Every one shrinks a little while
 * pressed (`press`, `buttonScale`). Disabled, a button keeps its colours and is drawn at
 * `states.disabled.opacity`; loading, it keeps its size and colours, shows a spinner instead of its label and
 * ignores taps.
 */

/**
 * A full-width button, `control` (56) tall, `button` shape, with a [text] label and an optional [leadingIcon]
 * (`iconSmall`, `inlineGap` from the label). While [isLoading], a spinner replaces the label.
 */
@Composable
public fun AwradButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    variant: AwradButtonVariant = AwradButtonVariant.Main,
    enabled: Boolean = true,
    isLoading: Boolean = false,
    leadingIcon: ImageVector? = null,
) {
    FilledButton(
        text = text,
        onClick = onClick,
        variant = variant,
        enabled = enabled,
        isLoading = isLoading,
        leadingIcon = leadingIcon,
        modifier = modifier
            .fillMaxWidth()
            .height(AwradTheme.sizes.control),
    )
}

/**
 * A button inside a row, such as signing out one device: `touchTarget` (48) tall and as wide as its label.
 * Otherwise like [AwradButton]; it defaults to [AwradButtonVariant.Secondary].
 */
@Composable
public fun AwradRowButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    variant: AwradButtonVariant = AwradButtonVariant.Secondary,
    enabled: Boolean = true,
    isLoading: Boolean = false,
    leadingIcon: ImageVector? = null,
) {
    FilledButton(
        text = text,
        onClick = onClick,
        variant = variant,
        enabled = enabled,
        isLoading = isLoading,
        leadingIcon = leadingIcon,
        modifier = modifier.height(AwradTheme.sizes.touchTarget),
    )
}

/**
 * A text-only action (links, "View all", a dialog's cancel): no fill, `accent` text in the `label` style, or
 * `error` when [isDestructive]; `touchTarget` tall.
 */
@Composable
public fun AwradTextButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    isDestructive: Boolean = false,
    leadingIcon: ImageVector? = null,
) {
    val content = if (isDestructive) AwradTheme.colors.error else AwradTheme.colors.accent
    ButtonFrame(
        onClick = onClick,
        enabled = enabled,
        isLoading = false,
        fill = Color.Transparent,
        modifier = modifier.heightIn(min = AwradTheme.sizes.touchTarget),
        horizontalPadding = AwradTheme.spacing.md,
    ) {
        ButtonLabel(
            text = text,
            color = content,
            style = AwradTheme.type.label,
            leadingIcon = leadingIcon,
            isLoading = false,
        )
    }
}

@Composable
private fun FilledButton(
    text: String,
    onClick: () -> Unit,
    variant: AwradButtonVariant,
    enabled: Boolean,
    isLoading: Boolean,
    leadingIcon: ImageVector?,
    modifier: Modifier = Modifier,
) {
    val colors = AwradTheme.colors
    val fill = when (variant) {
        AwradButtonVariant.Main -> colors.primary
        AwradButtonVariant.Secondary -> AwradTheme.secondaryFill
        AwradButtonVariant.Error -> colors.error
    }
    val content = when (variant) {
        AwradButtonVariant.Main -> colors.onPrimary
        AwradButtonVariant.Secondary -> AwradTheme.onSecondaryFill
        AwradButtonVariant.Error -> colors.onError
    }
    ButtonFrame(
        onClick = onClick,
        enabled = enabled,
        isLoading = isLoading,
        fill = fill,
        modifier = modifier,
        horizontalPadding = AwradTheme.spacing.lg,
    ) {
        ButtonLabel(
            text = text,
            color = content,
            style = AwradTheme.type.button,
            leadingIcon = leadingIcon,
            isLoading = isLoading,
        )
    }
}

/** The tappable, pressable shape every button shares. */
@Composable
private fun ButtonFrame(
    onClick: () -> Unit,
    enabled: Boolean,
    isLoading: Boolean,
    fill: Color,
    horizontalPadding: Dp,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val shape = AwradTheme.shapes.button
    val loading = stringResource(R.string.awrad_state_loading)
    Box(
        modifier = modifier
            .pressFeedback(interactionSource, AwradPressTarget.Button)
            .disabledOpacity(enabled)
            .clip(shape)
            .background(fill)
            .clickable(
                interactionSource = interactionSource,
                indication = ripple(),
                enabled = enabled && !isLoading,
                role = Role.Button,
                onClick = onClick,
            )
            .semantics { if (isLoading) stateDescription = loading }
            .padding(horizontal = horizontalPadding),
        contentAlignment = Alignment.Center,
    ) {
        content()
    }
}

/**
 * The label and its icon. While [isLoading] they stay laid out (so the button keeps its size) but invisible,
 * under a spinner in the same colour.
 */
@Composable
private fun ButtonLabel(
    text: String,
    color: Color,
    style: TextStyle,
    leadingIcon: ImageVector?,
    isLoading: Boolean,
    modifier: Modifier = Modifier,
) {
    Box(modifier = modifier, contentAlignment = Alignment.Center) {
        Row(
            modifier = Modifier.alpha(if (isLoading) 0f else 1f),
            horizontalArrangement = Arrangement.spacedBy(AwradTheme.spacing.inlineGap),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (leadingIcon != null) {
                Icon(
                    imageVector = leadingIcon,
                    contentDescription = null,
                    modifier = Modifier.size(AwradTheme.sizes.iconSmall),
                    tint = color,
                )
            }
            Text(text = text, color = color, style = style, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        if (isLoading) {
            CircularProgressIndicator(
                modifier = Modifier.size(AwradTheme.sizes.icon),
                color = color,
                strokeWidth = AwradTheme.sizes.ringStroke,
            )
        }
    }
}
