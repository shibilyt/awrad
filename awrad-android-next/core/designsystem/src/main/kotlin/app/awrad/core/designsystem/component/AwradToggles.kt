package app.awrad.core.designsystem.component

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.drawOutline
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.vector.rememberVectorPainter
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.IntOffset
import app.awrad.core.designsystem.icon.AwradIcons
import app.awrad.core.designsystem.motion.AwradPressTarget
import app.awrad.core.designsystem.motion.pressFeedback
import app.awrad.core.designsystem.motion.select
import app.awrad.core.designsystem.theme.AwradTheme

/*
 * Checkbox and switch (components.md, "Inputs"). Each is a whole row with its label: the row is the touch target
 * (at least 48 tall) and one node for screen readers, with the checkbox or switch role and its state.
 */

/**
 * A checkbox with its [label] (`body`, `md` after the box). The box is `checkbox` (20), `checkbox` shape:
 * unticked, a `strokes.checkbox` line in `outlineStrong`; ticked, a `primary` fill with an `onPrimary` tick (the
 * shared `check` icon) that draws in from its start on `spatial`. Colours change with `select`; under reduced
 * motion the tick cross-fades instead.
 */
@Composable
public fun AwradCheckbox(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    label: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    ToggleRow(
        value = checked,
        onValueChange = onCheckedChange,
        role = Role.Checkbox,
        enabled = enabled,
        modifier = modifier,
    ) {
        CheckboxBox(checked = checked)
        Text(text = label, style = AwradTheme.type.body, color = AwradTheme.colors.onSurface)
    }
}

/**
 * A switch with its [label] before it (`body`). The track is `switchWidth` × `switchHeight`, fully rounded, with
 * no outline: off, an `outline` track and a `background` thumb; on, a `primary` track and an `onPrimary` thumb.
 * The `switchThumb` slides on `spatial` (it jumps under reduced motion); colours change with `select`.
 */
@Composable
public fun AwradSwitch(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    label: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    ToggleRow(
        value = checked,
        onValueChange = onCheckedChange,
        role = Role.Switch,
        enabled = enabled,
        modifier = modifier.fillMaxWidth(),
    ) {
        Text(
            text = label,
            modifier = Modifier.weight(1f),
            style = AwradTheme.type.body,
            color = AwradTheme.colors.onSurface,
        )
        SwitchTrack(checked = checked)
    }
}

@Composable
private fun ToggleRow(
    value: Boolean,
    onValueChange: (Boolean) -> Unit,
    role: Role,
    enabled: Boolean,
    modifier: Modifier = Modifier,
    content: @Composable RowScope.() -> Unit,
) {
    val interactionSource = remember { MutableInteractionSource() }
    Row(
        modifier = modifier
            .pressFeedback(interactionSource, AwradPressTarget.Card)
            .disabledOpacity(enabled)
            .heightIn(min = AwradTheme.sizes.touchTarget)
            .toggleable(
                value = value,
                interactionSource = interactionSource,
                indication = null,
                enabled = enabled,
                role = role,
                onValueChange = onValueChange,
            ),
        horizontalArrangement = Arrangement.spacedBy(AwradTheme.spacing.md),
        verticalAlignment = Alignment.CenterVertically,
        content = content,
    )
}

@Composable
private fun CheckboxBox(checked: Boolean, modifier: Modifier = Modifier) {
    val colors = AwradTheme.colors
    val motion = AwradTheme.motion
    val fill by animateColorAsState(
        targetValue = if (checked) colors.primary else Color.Transparent,
        animationSpec = motion.select(),
        label = "checkboxFill",
    )
    val line by animateColorAsState(
        targetValue = if (checked) colors.primary else colors.outlineStrong,
        animationSpec = motion.select(),
        label = "checkboxLine",
    )
    // How much of the tick is drawn: it draws in on `spatial`, or fades in under reduced motion.
    val tick by animateFloatAsState(
        targetValue = if (checked) 1f else 0f,
        animationSpec = if (motion.isReduced) motion.crossfade() else motion.movement(),
        label = "checkboxTick",
    )
    val shape = AwradTheme.shapes.checkbox
    val stroke = AwradTheme.strokes.checkbox
    val tickColor = colors.onPrimary
    val check = rememberVectorPainter(AwradIcons.Check)
    Canvas(modifier = modifier.size(AwradTheme.sizes.checkbox)) {
        val width = stroke.toPx()
        drawOutline(shape.createOutline(size, layoutDirection, this), fill)
        // The line sits inside the box: inset by half its width.
        translate(width / 2, width / 2) {
            val inner = Size(size.width - width, size.height - width)
            drawOutline(shape.createOutline(inner, layoutDirection, this), line, style = Stroke(width))
        }
        if (tick > 0f) {
            val drawn = if (motion.isReduced) 1f else tick
            val alpha = if (motion.isReduced) tick else 1f
            // Drawing in reveals the check from its start (left; a tick isn't mirrored).
            clipRect(right = size.width * drawn) {
                with(check) { draw(size, alpha = alpha, colorFilter = ColorFilter.tint(tickColor)) }
            }
        }
    }
}

@Composable
private fun SwitchTrack(checked: Boolean, modifier: Modifier = Modifier) {
    val colors = AwradTheme.colors
    val motion = AwradTheme.motion
    val sizes = AwradTheme.sizes
    val track by animateColorAsState(
        targetValue = if (checked) colors.primary else colors.outline,
        animationSpec = motion.select(),
        label = "switchTrack",
    )
    val thumb by animateColorAsState(
        targetValue = if (checked) colors.onPrimary else colors.background,
        animationSpec = motion.select(),
        label = "switchThumb",
    )
    val inset = (sizes.switchHeight - sizes.switchThumb) / 2
    val travel = sizes.switchWidth - sizes.switchThumb - inset * 2
    val position by animateDpAsState(
        targetValue = if (checked) travel else AwradTheme.spacing.none,
        animationSpec = motion.movement(),
        label = "switchPosition",
    )
    val shape = AwradTheme.shapes.roundButton
    Box(
        modifier = modifier
            .size(width = sizes.switchWidth, height = sizes.switchHeight)
            .background(track, shape)
            .padding(inset),
        contentAlignment = Alignment.CenterStart,
    ) {
        // `offset` follows the layout direction, so the thumb slides the other way in RTL.
        Box(
            modifier = Modifier
                .offset { IntOffset(position.roundToPx(), 0) }
                .size(sizes.switchThumb)
                .background(thumb, shape),
        )
    }
}
