package app.awrad.awrad_dhikrgoalstracker.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.pager.PagerState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlin.math.abs

/**
 * PixelPlayer-style pill tabs bound to a [PagerState].
 *
 * Each tab is its own free-floating capsule: the active one is a filled accent pill, the others are
 * muted, and the fill + label colour cross-fade *continuously* between the outgoing and incoming
 * tab as the pager is swiped (tracking [PagerState.currentPageOffsetFraction]). The active pill
 * scales up a touch, and tapping a tab animates the pager to that page with a light haptic tick.
 *
 * The active-tab indicator "nub" is drawn by the caller on the content surface (see [onTabCenters],
 * which reports each pill's horizontal centre in root coordinates) so the line can sit on top of the
 * content area rather than floating beneath the pills.
 */
@Composable
fun AwradPagerTabs(
    tabs: List<String>,
    pagerState: PagerState,
    onTabSelected: (Int) -> Unit,
    modifier: Modifier = Modifier,
    onTabCenters: (List<Float>) -> Unit = {},
    selectedColor: Color = MaterialTheme.colorScheme.primary,
    unselectedColor: Color = MaterialTheme.colorScheme.surfaceContainerHighest,
    selectedLabelColor: Color = MaterialTheme.colorScheme.onPrimary,
    unselectedLabelColor: Color = MaterialTheme.colorScheme.onSurfaceVariant,
) {
    if (tabs.isEmpty()) return

    val haptics = LocalHapticFeedback.current
    val pillShape = RoundedCornerShape(percent = 50)

    // Continuous position across the tabs, e.g. 0.5 == half-way between tab 0 and tab 1.
    val position = (pagerState.currentPage + pagerState.currentPageOffsetFraction)
        .coerceIn(0f, (tabs.size - 1).toFloat())
    val settledPage = pagerState.currentPage.coerceIn(0, tabs.lastIndex)

    // Each pill reports its horizontal centre (root coords) so the caller can place the nub.
    val centers = remember(tabs.size) {
        mutableStateListOf<Float>().apply { repeat(tabs.size) { add(0f) } }
    }

    Row(
        modifier = modifier.selectableGroup(),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        tabs.forEachIndexed { index, label ->
            val selectedness = (1f - abs(position - index)).coerceIn(0f, 1f)
            val fillColor = lerp(unselectedColor, selectedColor, selectedness)
            val labelColor = lerp(unselectedLabelColor, selectedLabelColor, selectedness)
            val scale = 0.97f + 0.03f * selectedness
            val interaction = remember { MutableInteractionSource() }
            Box(
                modifier = Modifier
                    .onGloballyPositioned { coords ->
                        val center = coords.positionInRoot().x + coords.size.width / 2f
                        if (centers[index] != center) {
                            centers[index] = center
                            onTabCenters(centers.toList())
                        }
                    }
                    .graphicsLayer {
                        scaleX = scale
                        scaleY = scale
                    }
                    .clip(pillShape)
                    .background(fillColor)
                    .selectable(
                        selected = index == settledPage,
                        interactionSource = interaction,
                        indication = null,
                        role = Role.Tab,
                    ) {
                        haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                        onTabSelected(index)
                    }
                    .padding(horizontal = 22.dp, vertical = 11.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = label,
                    color = labelColor,
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                )
            }
        }
    }
}
