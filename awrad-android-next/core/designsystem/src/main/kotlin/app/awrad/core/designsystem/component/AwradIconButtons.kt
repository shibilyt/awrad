package app.awrad.core.designsystem.component

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.indication
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.ripple
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import app.awrad.core.designsystem.R
import app.awrad.core.designsystem.icon.AwradIcons
import app.awrad.core.designsystem.motion.AwradPressTarget
import app.awrad.core.designsystem.motion.pressFeedback
import app.awrad.core.designsystem.theme.AwradTheme

/**
 * An icon-only action (back, the three-dot menu): no fill, an `onSurface` [icon] at `icon` (24) in a
 * `touchTarget` (48) area. Pressed, it only shrinks (`press`); there's no ripple. [contentDescription] is
 * required: it's the button's only label. An auto-mirrored [icon] flips in RTL.
 */
@Composable
public fun AwradIconButton(
    icon: ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    tint: Color = AwradTheme.colors.onSurface,
) {
    val interactionSource = remember { MutableInteractionSource() }
    Box(
        modifier = modifier
            .pressFeedback(interactionSource, AwradPressTarget.Button)
            .disabledOpacity(enabled)
            .size(AwradTheme.sizes.touchTarget)
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                enabled = enabled,
                role = Role.Button,
                onClick = onClick,
            )
            .semantics { this.contentDescription = contentDescription },
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(AwradTheme.sizes.icon),
            tint = tint,
        )
    }
}

/** Back: the shared `back` chevron (flipped in RTL) labelled "Back" in the app's language. */
@Composable
public fun AwradBackButton(onClick: () -> Unit, modifier: Modifier = Modifier, enabled: Boolean = true) {
    AwradIconButton(
        icon = AwradIcons.Back,
        contentDescription = stringResource(R.string.awrad_action_back),
        onClick = onClick,
        modifier = modifier,
        enabled = enabled,
    )
}

/**
 * A round `primary` button with an `onPrimary` [icon], fully rounded. [contentDescription] is required: it's
 * the button's only label.
 */
@Composable
public fun AwradRoundButton(
    icon: ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    size: AwradRoundButtonSize = AwradRoundButtonSize.Regular,
    enabled: Boolean = true,
) {
    val sizes = AwradTheme.sizes
    val (diameter, iconSize) = when (size) {
        AwradRoundButtonSize.Regular -> sizes.roundButton to sizes.icon
        AwradRoundButtonSize.Small -> sizes.roundButtonSmall to sizes.iconSmall
    }
    val interactionSource = remember { MutableInteractionSource() }
    // The touch target is at least 48 even when the circle is smaller.
    Box(
        modifier = modifier
            .pressFeedback(interactionSource, AwradPressTarget.Button)
            .disabledOpacity(enabled)
            .size(maxOf(diameter, sizes.touchTarget))
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                enabled = enabled,
                role = Role.Button,
                onClick = onClick,
            )
            .semantics { this.contentDescription = contentDescription },
        contentAlignment = Alignment.Center,
    ) {
        RoundFill(diameter = diameter, interactionSource = interactionSource) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(iconSize),
                tint = AwradTheme.colors.onPrimary,
            )
        }
    }
}

/** The visible circle. */
@Composable
private fun RoundFill(
    diameter: Dp,
    interactionSource: MutableInteractionSource,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    val shape = AwradTheme.shapes.roundButton
    Box(
        modifier = modifier
            .size(diameter)
            .clip(shape)
            .background(AwradTheme.colors.primary)
            // The ripple shows on the circle, not the whole touch target.
            .indication(interactionSource, ripple()),
        contentAlignment = Alignment.Center,
    ) {
        content()
    }
}
