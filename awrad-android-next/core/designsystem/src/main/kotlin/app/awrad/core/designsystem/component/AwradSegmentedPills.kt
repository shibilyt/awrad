package app.awrad.core.designsystem.component

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.material3.Text
import androidx.compose.material3.ripple
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.drawOutline
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.layout.boundsInParent
import androidx.compose.ui.layout.onPlaced
import androidx.compose.ui.semantics.Role
import app.awrad.core.designsystem.motion.segmentColor
import app.awrad.core.designsystem.motion.segmentIndicator
import app.awrad.core.designsystem.theme.AwradTheme
import kotlinx.coroutines.launch

/**
 * Two to four mutually exclusive views, such as Active / History (components.md, "Segmented pills"). Each pill
 * is `chip` shaped, `touchTarget` tall, padded `lg`, with a `button` label; pills are `sm` apart. Unselected
 * pills are `secondaryContainer` with an `onSecondaryContainer` label (on a `surface` area, `background` with
 * `onSurface`); the selected one is `primary` with an
 * `onPrimary` label and a `tabIndicatorWidth` × `tabIndicatorHeight` bar `xs` below it. The fill and bar move to
 * a newly selected pill on `segmentIndicator` (`spatial`); under reduced motion they cross-fade. Screen readers
 * announce the pills as tabs. Tapping the selected pill does nothing.
 */
@Composable
public fun AwradSegmentedPills(
    options: List<String>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    requireSegments(options.size, selectedIndex)
    val bounds = remember(options.size) { mutableStateListOf<Rect?>().apply { repeat(options.size) { add(null) } } }
    val indicator = rememberIndicator(target = bounds.getOrNull(selectedIndex), selectedIndex = selectedIndex)
    val colors = AwradTheme.colors
    val unselectedFill = AwradTheme.secondaryFill
    val spacing = AwradTheme.spacing
    val sizes = AwradTheme.sizes
    val pill = AwradTheme.shapes.chip
    val bar = AwradTheme.shapes.tabIndicator
    Row(
        modifier = modifier
            .disabledOpacity(enabled)
            .selectableGroup()
            .drawBehind {
                bounds.forEach { rect -> rect?.let { drawShape(pill, it, unselectedFill) } }
                indicator.draw { rect, alpha ->
                    drawShape(pill, rect, colors.primary.copy(alpha = alpha))
                    val barSize = Size(sizes.tabIndicatorWidth.toPx(), sizes.tabIndicatorHeight.toPx())
                    val barTop = rect.bottom + spacing.xs.toPx()
                    val barRect = Rect(Offset(rect.center.x - barSize.width / 2, barTop), barSize)
                    drawShape(bar, barRect, colors.primary.copy(alpha = alpha))
                }
            }
            .padding(bottom = spacing.xs + sizes.tabIndicatorHeight),
        horizontalArrangement = Arrangement.spacedBy(spacing.sm),
    ) {
        options.forEachIndexed { index, option ->
            Pill(
                label = option,
                selected = index == selectedIndex,
                enabled = enabled,
                onClick = { segmentToSelect(selectedIndex, index)?.let(onSelect) },
                modifier = Modifier.onPlaced { bounds[index] = it.boundsInParent() },
            )
        }
    }
}

@Composable
private fun Pill(
    label: String,
    selected: Boolean,
    enabled: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = AwradTheme.colors
    val content by animateColorAsState(
        targetValue = if (selected) colors.onPrimary else AwradTheme.onSecondaryFill,
        animationSpec = AwradTheme.motion.segmentColor(),
        label = "segmentLabel",
    )
    Box(
        modifier = modifier
            .height(AwradTheme.sizes.touchTarget)
            .clip(AwradTheme.shapes.chip)
            .selectable(
                selected = selected,
                indication = ripple(),
                interactionSource = null,
                enabled = enabled,
                role = Role.Tab,
                onClick = onClick,
            )
            .padding(horizontal = AwradTheme.spacing.lg),
        contentAlignment = Alignment.Center,
    ) {
        Text(text = label, style = AwradTheme.type.button, color = content, maxLines = 1)
    }
}

/**
 * Where the selected fill is drawn. Normally it moves: its left and right edges spring to the new pill. Under
 * reduced motion it stays put and cross-fades: the old pill's fill fades out while the new one's fades in.
 */
private class SegmentIndicator {
    val left = Animatable(0f)
    val right = Animatable(0f)
    val fade = Animatable(1f)
    var top by mutableFloatStateOf(0f)
    var bottom by mutableFloatStateOf(0f)
    var previous by mutableStateOf<Rect?>(null)
    var isPlaced by mutableStateOf(false)

    fun draw(drawFill: (Rect, Float) -> Unit) {
        if (!isPlaced) return
        val fadeIn = fade.value
        previous?.let { if (fadeIn < 1f) drawFill(it, 1f - fadeIn) }
        drawFill(Rect(left.value, top, right.value, bottom), fadeIn)
    }
}

@Composable
private fun rememberIndicator(target: Rect?, selectedIndex: Int): SegmentIndicator {
    val indicator = remember { SegmentIndicator() }
    val motion = AwradTheme.motion
    LaunchedEffect(target, selectedIndex, motion) {
        if (target == null) return@LaunchedEffect
        indicator.top = target.top
        indicator.bottom = target.bottom
        if (!indicator.isPlaced || motion.isReduced) {
            val from = if (indicator.isPlaced) {
                Rect(indicator.left.value, target.top, indicator.right.value, target.bottom)
            } else {
                null
            }
            indicator.left.snapTo(target.left)
            indicator.right.snapTo(target.right)
            val fades = from != null && from != target
            indicator.previous = if (fades) from else null
            indicator.isPlaced = true
            if (fades) {
                indicator.fade.snapTo(0f)
                indicator.fade.animateTo(1f, motion.crossfade())
            }
            indicator.previous = null
            return@LaunchedEffect
        }
        launch { indicator.left.animateTo(target.left, motion.segmentIndicator()) }
        launch { indicator.right.animateTo(target.right, motion.segmentIndicator()) }
    }
    return indicator
}

private fun DrawScope.drawShape(shape: Shape, rect: Rect, color: Color) {
    if (rect.width <= 0f || rect.height <= 0f) return
    translate(rect.left, rect.top) {
        drawOutline(shape.createOutline(rect.size, layoutDirection, this), color)
    }
}
