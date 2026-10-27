package app.awrad.core.designsystem.component

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import app.awrad.core.designsystem.R
import app.awrad.core.designsystem.motion.select
import app.awrad.core.designsystem.theme.AwradTheme

/**
 * The top bar (components.md, "Top bar"): `topBar` (56) tall, with no fill (it sits on the screen background)
 * and no divider. At the start an optional Back button ([onBack]); in the middle the [title] (`title` style) or
 * any [center] content such as [AwradStepIndicator]; at the end up to two icon buttons or a text button
 * ([actions]). Icons line up with the page margin: the bar is inset `pageMargin` less an icon button's padding.
 */
@Composable
public fun AwradTopBar(
    modifier: Modifier = Modifier,
    title: String? = null,
    onBack: (() -> Unit)? = null,
    center: (@Composable () -> Unit)? = null,
    actions: @Composable RowScope.() -> Unit = {},
) {
    Layout(
        modifier = modifier
            .fillMaxWidth()
            .height(AwradTheme.sizes.topBar)
            .padding(horizontal = topBarInset()),
        content = {
            Box { if (onBack != null) AwradBackButton(onClick = onBack) }
            Box(contentAlignment = Alignment.Center) {
                when {
                    center != null -> center()
                    title != null -> Text(
                        text = title,
                        modifier = Modifier.semantics { heading() },
                        style = AwradTheme.type.title,
                        color = AwradTheme.colors.onSurface,
                        textAlign = TextAlign.Center,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically, content = actions)
        },
    ) { measurables, constraints ->
        val loose = constraints.copy(minWidth = 0, minHeight = 0)
        val start = measurables[0].measure(loose)
        val end = measurables[2].measure(loose)
        // The middle stays centred on the bar, so it may use what's left on its narrower side, twice.
        val side = maxOf(start.width, end.width)
        val middleWidth = (constraints.maxWidth - side * 2).coerceAtLeast(0)
        val middle = measurables[1].measure(Constraints(maxWidth = middleWidth, maxHeight = constraints.maxHeight))
        val height = constraints.maxHeight
        layout(constraints.maxWidth, height) {
            start.placeRelative(0, (height - start.height) / 2)
            middle.placeRelative((constraints.maxWidth - middle.width) / 2, (height - middle.height) / 2)
            end.placeRelative(constraints.maxWidth - end.width, (height - end.height) / 2)
        }
    }
}

/** `pageMargin` less the space an icon button leaves around its icon, so its icon lines up with the page. */
@Composable
internal fun topBarInset(): Dp {
    val sizes = AwradTheme.sizes
    return AwradTheme.spacing.pageMargin - (sizes.touchTarget - sizes.icon) / 2
}

/**
 * The position in a fixed flow, such as onboarding (components.md, "Step indicator"): one `stepDot` square per
 * step, `xs` apart; done and current steps are `onSurface`, steps ahead `outline`. [step] is 1-based. Screen
 * readers hear "Step 2 of 7", not the squares; the order mirrors in RTL.
 */
@Composable
public fun AwradStepIndicator(step: Int, count: Int, modifier: Modifier = Modifier) {
    val states = stepStates(step, count)
    val description = stringResource(R.string.awrad_step_indicator, step, count)
    Row(
        modifier = modifier.clearAndSetSemantics { contentDescription = description },
        horizontalArrangement = Arrangement.spacedBy(AwradTheme.spacing.xs),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        states.forEach { state -> StepDot(isReached = state != StepState.Ahead) }
    }
}

@Composable
private fun StepDot(isReached: Boolean, modifier: Modifier = Modifier) {
    val colors = AwradTheme.colors
    val color by animateColorAsState(
        targetValue = if (isReached) colors.onSurface else colors.outline,
        animationSpec = AwradTheme.motion.select(),
        label = "stepDot",
    )
    Box(
        modifier = modifier
            .size(AwradTheme.sizes.stepDot)
            .background(color, AwradTheme.shapes.stepDot),
    )
}
