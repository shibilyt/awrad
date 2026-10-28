package app.awrad.core.designsystem.component

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextOverflow
import app.awrad.core.designsystem.icon.AwradIcons
import app.awrad.core.designsystem.motion.AwradPressTarget
import app.awrad.core.designsystem.motion.pressFeedback
import app.awrad.core.designsystem.motion.select
import app.awrad.core.designsystem.theme.AwradTheme

/**
 * A label in a pill, such as a dhikr's tag: the `chip` shape (fully rounded) filled like a secondary control
 * (`secondaryContainer` on the page, `background` on a `surface` area), the [text] in `label` with its content
 * colour, padded `sm` by `md`. It isn't tappable.
 */
@Composable
public fun AwradChip(text: String, modifier: Modifier = Modifier) {
    val spacing = AwradTheme.spacing
    Text(
        text = text,
        modifier = modifier
            .background(AwradTheme.secondaryFill, AwradTheme.shapes.chip)
            .padding(horizontal = spacing.md, vertical = spacing.sm),
        style = AwradTheme.type.label,
        color = AwradTheme.onSecondaryFill,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
    )
}

/**
 * A filter chip (components.md, "Filter chip"; the Library's tag filter): the same pill, toggled, and several can
 * be selected at once. Unselected it's the display chip (`secondaryContainer`, or `background` on a surface, with
 * an `onSecondaryContainer` label); selected it's `primary` with an `onPrimary` label after a leading `check`
 * icon (`iconSmall`, `inlineGap` to the label). Colours change with `select`, it presses like a button inside a
 * `touchTarget` height, and screen readers announce it as a toggle button named by its label, with its state.
 */
@Composable
public fun AwradChip(
    text: String,
    selected: Boolean,
    onSelectedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    val colors = AwradTheme.colors
    val motion = AwradTheme.motion
    val spacing = AwradTheme.spacing
    val fill by animateColorAsState(
        targetValue = if (selected) colors.primary else AwradTheme.secondaryFill,
        animationSpec = motion.select(),
        label = "chipFill",
    )
    val content by animateColorAsState(
        targetValue = if (selected) colors.onPrimary else AwradTheme.onSecondaryFill,
        animationSpec = motion.select(),
        label = "chipLabel",
    )
    val interactionSource = remember { MutableInteractionSource() }
    Box(
        modifier = modifier
            .disabledOpacity(enabled)
            .heightIn(min = AwradTheme.sizes.touchTarget)
            .toggleable(
                value = selected,
                interactionSource = interactionSource,
                indication = null,
                enabled = enabled,
                // A checkable button: TalkBack announces it as a toggle button, on or off.
                role = Role.Button,
                onValueChange = onSelectedChange,
            ),
        contentAlignment = Alignment.Center,
    ) {
        Row(
            modifier = Modifier
                .pressFeedback(interactionSource, AwradPressTarget.Button)
                .clip(AwradTheme.shapes.chip)
                .background(fill)
                .padding(horizontal = spacing.md, vertical = spacing.sm),
            horizontalArrangement = Arrangement.spacedBy(spacing.inlineGap),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (selected) {
                Icon(
                    imageVector = AwradIcons.Check,
                    contentDescription = null,
                    modifier = Modifier.size(AwradTheme.sizes.iconSmall),
                    tint = content,
                )
            }
            Text(
                text = text,
                style = AwradTheme.type.label,
                color = content,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}
