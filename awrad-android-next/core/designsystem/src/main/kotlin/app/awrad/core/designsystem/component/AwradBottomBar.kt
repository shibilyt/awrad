package app.awrad.core.designsystem.component

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.foundation.background
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextOverflow
import app.awrad.core.designsystem.motion.AwradPressTarget
import app.awrad.core.designsystem.motion.navPill
import app.awrad.core.designsystem.motion.pressFeedback
import app.awrad.core.designsystem.motion.rememberAwradHaptics
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.core.designsystem.theme.awradShadow
import kotlinx.coroutines.launch

/**
 * The floating main navigation (components.md, "Bottom bar"): `navBar` (72) tall, `surfaceBar`, `navBar` shape,
 * the `floating` shadow (none in dark), inset `pageMargin` from the sides and `lg` above the navigation bar.
 * Items share the width equally: icon (`icon`) over label (`navLabel`), `onSurfaceVariant`; the selected one has
 * a `primaryContainer` pill behind an `onPrimaryContainer` icon and an `accent` label. Selecting an item plays
 * `navPill` (the pill grows in, the icon pops, colours change over `color`) and a `tick` haptic. Screen readers
 * announce it as a tab bar with each item's state; the order mirrors in RTL. Animate the content swap with
 * `AwradTheme.motion.tabSwitch()`, and pad it with [awradBottomBarPadding] so its last item clears the bar.
 */
@Composable
public fun AwradBottomBar(
    items: List<AwradBottomBarItem>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    require(selectedIndex in items.indices) { "selectedIndex must be in ${items.indices}, was $selectedIndex" }
    val haptics = rememberAwradHaptics()
    val shape = AwradTheme.shapes.navBar
    Row(
        modifier = modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .padding(horizontal = AwradTheme.spacing.pageMargin)
            .padding(bottom = AwradTheme.spacing.lg)
            .height(AwradTheme.sizes.navBar)
            .awradShadow(AwradTheme.elevation.floating, shape)
            .clip(shape)
            .background(AwradTheme.colors.surfaceBar)
            .selectableGroup(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        items.forEachIndexed { index, item ->
            BarItem(
                item = item,
                selected = index == selectedIndex,
                onClick = {
                    if (index != selectedIndex) {
                        haptics.tick()
                        onSelect(index)
                    }
                },
                modifier = Modifier.weight(1f),
            )
        }
    }
}

/**
 * Bottom padding for content behind an [AwradBottomBar], so its last item scrolls clear of the bar: the bar,
 * the `lg` gap under it and the navigation bar, plus `lg`.
 */
@Composable
public fun awradBottomBarPadding(): PaddingValues {
    val navigation = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    return PaddingValues(bottom = AwradTheme.sizes.navBar + AwradTheme.spacing.lg * 2 + navigation)
}

/** [content] filling the screen with [bottomBar] floating over its bottom edge. */
@Composable
public fun AwradBottomBarLayout(
    bottomBar: @Composable () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    Box(modifier = modifier.fillMaxSize()) {
        content()
        Box(modifier = Modifier.align(Alignment.BottomCenter)) { bottomBar() }
    }
}

@Composable
private fun BarItem(
    item: AwradBottomBarItem,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = AwradTheme.colors
    val labelColor by animateColorAsState(
        targetValue = if (selected) colors.accent else colors.onSurfaceVariant,
        animationSpec = AwradTheme.motion.navPill.color(),
        label = "navLabel",
    )
    val interactionSource = remember { MutableInteractionSource() }
    Column(
        modifier = modifier
            .fillMaxHeight()
            .pressFeedback(interactionSource, AwradPressTarget.Button)
            .selectable(
                selected = selected,
                interactionSource = interactionSource,
                indication = null,
                role = Role.Tab,
                onClick = onClick,
            ),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.xs, Alignment.CenterVertically),
    ) {
        PillIcon(icon = item.icon, selected = selected)
        Text(
            text = item.label,
            style = AwradTheme.type.navLabel,
            color = labelColor,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

/** The icon, and the pill behind it while selected: the pill grows in and the icon pops when it's selected. */
@Composable
private fun PillIcon(icon: ImageVector, selected: Boolean, modifier: Modifier = Modifier) {
    val colors = AwradTheme.colors
    val pillMotion = AwradTheme.motion.navPill
    val pill by animateColorAsState(
        targetValue = if (selected) colors.primaryContainer else colors.primaryContainer.copy(alpha = 0f),
        animationSpec = pillMotion.color(),
        label = "navPill",
    )
    val iconColor by animateColorAsState(
        targetValue = if (selected) colors.onPrimaryContainer else colors.onSurfaceVariant,
        animationSpec = pillMotion.color(),
        label = "navIcon",
    )
    val pillScale = remember { Animatable(1f) }
    val iconScale = remember { Animatable(1f) }
    // Only a change of selection animates, not the first frame.
    var wasSelected by remember { mutableStateOf(selected) }
    LaunchedEffect(selected) {
        val becameSelected = selected && !wasSelected
        wasSelected = selected
        if (!becameSelected) return@LaunchedEffect
        launch {
            pillScale.snapTo(pillMotion.pillScaleFrom)
            pillScale.animateTo(1f, pillMotion.pillScale)
        }
        launch {
            iconScale.animateTo(pillMotion.selectedIconScale, pillMotion.iconScale)
            iconScale.animateTo(1f, pillMotion.iconScale)
        }
    }
    Box(
        modifier = modifier.size(width = AwradTheme.sizes.navPillWidth, height = AwradTheme.sizes.navPillHeight),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .graphicsLayer {
                    scaleX = pillScale.value
                    scaleY = pillScale.value
                }
                .background(pill, AwradTheme.shapes.navPill),
        )
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier
                .size(AwradTheme.sizes.icon)
                .graphicsLayer {
                    scaleX = iconScale.value
                    scaleY = iconScale.value
                },
            tint = iconColor,
        )
    }
}
