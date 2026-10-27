package app.awrad.core.designsystem.component

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Constraints
import app.awrad.core.designsystem.theme.AwradTheme
import kotlin.math.roundToInt

/**
 * The top of a main tab, such as My Goals (components.md, "Large-title header"): the [title] in `largeTitle`,
 * `onSurface`, at the start, with an optional [action] (a round button) at the end, aligned with it; [content]
 * (segmented pills, a content sheet) follows `lg` below.
 *
 * The header scrolls away with the content: scrolling [content] (any scrollable inside it, such as
 * [AwradContentSheet]) first moves the header up, then scrolls. Once the title has gone under it, a compact top
 * bar with the title in `title` style fades in (`contentSwap`). Scrolling back down brings the header back
 * before the content scrolls past its top.
 */
@Composable
public fun AwradLargeTitlePage(
    title: String,
    modifier: Modifier = Modifier,
    action: (@Composable () -> Unit)? = null,
    content: @Composable () -> Unit,
) {
    val state = remember { LargeTitleState() }
    val topBarHeight = AwradTheme.sizes.topBar
    val motion = AwradTheme.motion
    Layout(
        modifier = modifier
            .clipToBounds()
            .nestedScroll(state.connection),
        contents = listOf(
            { LargeTitleHeader(title = title, action = action) },
            content,
            {
                AnimatedVisibility(
                    visible = state.isCollapsed,
                    enter = motion.contentSwap().targetContentEnter,
                    exit = motion.contentSwap().initialContentExit,
                    label = "compactTitle",
                ) {
                    AwradTopBar(
                        title = title,
                        modifier = Modifier.background(AwradTheme.colors.background),
                    )
                }
            },
        ),
    ) { (header, body, compact), constraints ->
        val loose = constraints.copy(minHeight = 0)
        val headerPlaceable = header.first().measure(loose)
        val headerHeight = headerPlaceable.height
        state.collapseRange = (headerHeight - topBarHeight.roundToPx()).coerceAtLeast(0)
        val offset = state.offset.roundToInt()
        val bodyTop = headerHeight + offset
        val bodyHeight = (constraints.maxHeight - bodyTop).coerceAtLeast(0)
        val bodyPlaceables = body.map {
            it.measure(Constraints.fixed(constraints.maxWidth, bodyHeight))
        }
        val compactPlaceables = compact.map { it.measure(loose) }
        layout(constraints.maxWidth, constraints.maxHeight) {
            headerPlaceable.placeRelative(0, offset)
            bodyPlaceables.forEach { it.placeRelative(0, bodyTop) }
            compactPlaceables.forEach { it.placeRelative(0, 0) }
        }
    }
}

@Composable
private fun LargeTitleHeader(title: String, action: (@Composable () -> Unit)?, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(start = AwradTheme.spacing.pageMargin, end = AwradTheme.spacing.pageMargin)
            .padding(bottom = AwradTheme.spacing.lg),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = title,
            modifier = Modifier
                .weight(1f)
                .semantics { heading() },
            style = AwradTheme.type.largeTitle,
            color = AwradTheme.colors.onSurface,
        )
        action?.invoke()
    }
}

/**
 * How far the header has scrolled away: [offset] runs from 0 (shown) to minus [collapseRange] (only a top bar's
 * height of it left, under the compact bar). Scrolling up takes the header away before the content scrolls;
 * scrolling down brings it back once the content is at its top.
 */
@Stable
private class LargeTitleState {
    var offset by mutableFloatStateOf(0f)
    var collapseRange by mutableIntStateOf(0)

    val isCollapsed: Boolean get() = collapseRange > 0 && offset <= -collapseRange + 1f

    val connection = object : NestedScrollConnection {
        override fun onPreScroll(available: Offset, source: NestedScrollSource): Offset =
            if (available.y < 0f) Offset(0f, consume(available.y)) else Offset.Zero

        override fun onPostScroll(consumed: Offset, available: Offset, source: NestedScrollSource): Offset =
            if (available.y > 0f) Offset(0f, consume(available.y)) else Offset.Zero
    }

    /** Moves the header by [delta] within its range and returns how much of [delta] that used. */
    private fun consume(delta: Float): Float {
        val next = (offset + delta).coerceIn(-collapseRange.toFloat(), 0f)
        val used = next - offset
        offset = next
        return used
    }
}
