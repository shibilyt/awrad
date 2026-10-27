package app.awrad.core.designsystem.component

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.ripple
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.style.TextOverflow
import app.awrad.core.designsystem.icon.AwradIcons
import app.awrad.core.designsystem.motion.AwradPressTarget
import app.awrad.core.designsystem.motion.pressFeedback
import app.awrad.core.designsystem.motion.select
import app.awrad.core.designsystem.theme.AwradTheme

/**
 * A selectable row in a list of options, such as a language (components.md, "Option row"): `listRow` tall,
 * `tile` shape, padded `md`, with an optional round [avatar] (`avatar`, a short text such as "Aa") `md` before
 * the [label] (`rowTitle`).
 *
 * Unselected, it's `secondaryContainer` with an `onSecondaryContainer` label (on a `surface` area, `background`
 * with `onSurface`) and a `background` avatar; selected,
 * `primary` with an `onPrimaryVariant` label and avatar fill, and a check in an `onPrimary` circle at the end.
 * Colours change with `select`. Screen readers announce it as a radio button ([AwradSelectionMode.Single]) or a
 * checkbox ([AwradSelectionMode.Multiple]) with its state. Lay rows out `rowGap` apart.
 */
@Composable
public fun AwradOptionRow(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    avatar: String? = null,
    mode: AwradSelectionMode = AwradSelectionMode.Single,
    enabled: Boolean = true,
) {
    val colors = AwradTheme.colors
    val motion = AwradTheme.motion
    val fill by animateColorAsState(
        targetValue = if (selected) colors.primary else AwradTheme.secondaryFill,
        animationSpec = motion.select(),
        label = "optionFill",
    )
    val text by animateColorAsState(
        targetValue = if (selected) colors.onPrimaryVariant else AwradTheme.onSecondaryFill,
        animationSpec = motion.select(),
        label = "optionLabel",
    )
    val interactionSource = remember { MutableInteractionSource() }
    val role = optionRowRole(mode)
    val selection = when (mode) {
        AwradSelectionMode.Single -> Modifier.selectable(
            selected = selected,
            interactionSource = interactionSource,
            indication = ripple(),
            enabled = enabled,
            role = role,
            onClick = onClick,
        )
        AwradSelectionMode.Multiple -> Modifier.toggleable(
            value = selected,
            interactionSource = interactionSource,
            indication = ripple(),
            enabled = enabled,
            role = role,
            onValueChange = { onClick() },
        )
    }
    Row(
        modifier = modifier
            .pressFeedback(interactionSource, AwradPressTarget.Card)
            .disabledOpacity(enabled)
            .fillMaxWidth()
            .height(AwradTheme.sizes.listRow)
            .clip(AwradTheme.shapes.tile)
            .background(fill)
            .then(selection)
            .padding(horizontal = AwradTheme.spacing.md),
        horizontalArrangement = Arrangement.spacedBy(AwradTheme.spacing.md),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (avatar != null) OptionAvatar(text = avatar, selected = selected)
        Text(
            text = label,
            modifier = Modifier.weight(1f),
            style = AwradTheme.type.rowTitle,
            color = text,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        SelectedCheck(selected = selected)
    }
}

@Composable
private fun OptionAvatar(text: String, selected: Boolean, modifier: Modifier = Modifier) {
    val colors = AwradTheme.colors
    val motion = AwradTheme.motion
    val fill by animateColorAsState(
        targetValue = if (selected) colors.onPrimaryVariant else colors.background,
        animationSpec = motion.select(),
        label = "avatarFill",
    )
    val content by animateColorAsState(
        targetValue = if (selected) colors.primary else colors.onSurface,
        animationSpec = motion.select(),
        label = "avatarText",
    )
    Box(
        modifier = modifier
            .size(AwradTheme.sizes.avatar)
            .background(fill, AwradTheme.shapes.roundButton)
            // Decorative: the label says which option this is.
            .clearAndSetSemantics {},
        contentAlignment = Alignment.Center,
    ) {
        Text(text = text, style = AwradTheme.type.label, color = content, maxLines = 1)
    }
}

/** The check in a circle; it fades in and out with `select` and always keeps its space. */
@Composable
private fun SelectedCheck(selected: Boolean, modifier: Modifier = Modifier) {
    val visibility by animateFloatAsState(
        targetValue = if (selected) 1f else 0f,
        animationSpec = AwradTheme.motion.select(),
        label = "optionCheck",
    )
    Box(
        modifier = modifier
            .size(AwradTheme.sizes.icon)
            .alpha(visibility)
            .background(AwradTheme.colors.onPrimary, AwradTheme.shapes.roundButton),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = AwradIcons.Check,
            contentDescription = null,
            modifier = Modifier.size(AwradTheme.sizes.iconSmall),
            tint = AwradTheme.colors.primary,
        )
    }
}
