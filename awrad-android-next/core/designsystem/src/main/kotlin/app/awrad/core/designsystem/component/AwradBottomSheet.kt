package app.awrad.core.designsystem.component

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animate
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CornerSize
import androidx.compose.foundation.shape.ZeroCornerSize
import androidx.compose.material3.LocalContentColor
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import app.awrad.core.designsystem.R
import app.awrad.core.designsystem.motion.AwradMotion
import app.awrad.core.designsystem.motion.sheet
import app.awrad.core.designsystem.theme.AwradContainer
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.core.designsystem.theme.LocalAwradContainer
import app.awrad.core.designsystem.theme.SmoothCornerShape
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/**
 * A modal bottom sheet (components.md, "Bottom sheet"): `surfaceBar` fill, `sheet` (32) top corners, the
 * `scrim` behind, and a drag handle (`outline`, `tabIndicator` shape) that also closes it for screen readers.
 * It shows while composed and runs the `sheet` motion: it rises and settles on the `spatial` spring, follows the
 * finger, settles with the fling's speed (a downward fling faster than `releaseVelocity` closes it), grows to at
 * most `overshootScale` when pulled past open, and its corners reach 0 at full height. Under reduced motion it
 * cross-fades in and out instead of sliding.
 *
 * Dragging it down, tapping the scrim or Back plays the closing motion, then calls [onDismissRequest]; stop
 * composing it then.
 */
// `modifier` styles the sheet, not the full-screen window it shows in (which has the scrim).
@Suppress("ModifierNotUsedAtRoot")
@Composable
public fun AwradBottomSheet(
    onDismissRequest: () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    val state = remember { SheetState() }
    val scope = rememberCoroutineScope()
    val motion = AwradTheme.motion
    val currentOnDismiss by rememberUpdatedState(onDismissRequest)
    val releaseVelocity = with(LocalDensity.current) { Dp(motion.sheet.releaseVelocity).toPx() }
    val dismiss: (Float) -> Unit = { velocity ->
        state.run(scope) {
            state.close(motion, velocity)
            currentOnDismiss()
        }
    }
    LaunchedEffect(state.height) {
        if (state.height > 0 && !state.isShown) state.run(scope) { state.open(motion, fromHidden = true) }
    }
    OverlayWindow(onDismissRequest = { dismiss(0f) }, animatesItself = true) {
        Box(modifier = Modifier.fillMaxSize()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .graphicsLayer { alpha = state.visibility(motion) }
                    .background(AwradTheme.colors.scrim)
                    .pointerInput(Unit) { detectTapGestures { dismiss(0f) } },
            )
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .statusBarsPadding()
                    .onSizeChanged { state.areaHeight = it.height },
                contentAlignment = Alignment.BottomCenter,
            ) {
                SheetBody(
                    state = state,
                    onRelease = { velocity ->
                        when {
                            velocity > releaseVelocity -> dismiss(velocity)
                            velocity < -releaseVelocity -> state.run(scope) { state.open(motion, velocity = velocity) }
                            state.position > state.height / 2f -> dismiss(velocity)
                            else -> state.run(scope) { state.open(motion, velocity = velocity) }
                        }
                    },
                    onClose = { dismiss(0f) },
                    modifier = modifier,
                    content = content,
                )
            }
        }
    }
}

@Composable
private fun SheetBody(
    state: SheetState,
    onRelease: (Float) -> Unit,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    val motion = AwradTheme.motion
    val sheet = motion.sheet
    val radius = with(LocalDensity.current) { sheet.radius.toPx() }
    val draggable = rememberDraggableState { delta -> state.position += delta }
    Column(
        modifier = modifier
            .fillMaxWidth()
            .onSizeChanged { state.height = it.height }
            .graphicsLayer {
                translationY = state.position.coerceAtLeast(0f)
                // Pulled past open, it grows toward `overshootScale` from its bottom edge.
                val pull = (-state.position).coerceAtLeast(0f)
                val grow = if (state.height == 0) 0f else pull / (pull + state.height)
                val scale = 1f + (sheet.overshootScale - 1f) * grow
                scaleX = scale
                scaleY = scale
                transformOrigin = TransformOrigin(pivotFractionX = 0.5f, pivotFractionY = 1f)
                alpha = if (!state.isShown) 0f else if (motion.isReduced) state.fade.value else 1f
                // The corners shrink to 0 as the top edge reaches the top of the screen.
                val top = state.areaHeight - state.height + translationY
                val corner = radius * (top / radius).coerceIn(0f, 1f)
                shape = SmoothCornerShape(CornerSize(corner), CornerSize(corner), ZeroCornerSize, ZeroCornerSize)
                clip = true
            }
            .background(AwradTheme.colors.surfaceBar)
            .draggable(
                state = draggable,
                orientation = Orientation.Vertical,
                onDragStarted = { state.stop() },
                onDragStopped = { velocity -> onRelease(velocity) },
            )
            .navigationBarsPadding()
            .imePadding(),
    ) {
        DragHandle(onClose = onClose)
        // A sheet counts as the page: secondary controls in it fill with `secondaryContainer`.
        CompositionLocalProvider(
            LocalAwradContainer provides AwradContainer.Background,
            LocalContentColor provides AwradTheme.colors.onSurface,
        ) {
            Column(
                modifier = Modifier.padding(
                    start = AwradTheme.spacing.pageMargin,
                    end = AwradTheme.spacing.pageMargin,
                    bottom = AwradTheme.spacing.lg,
                ),
                verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.rowGap),
                content = content,
            )
        }
    }
}

/** The handle: `outline`, as wide as `xl3` and as tall as the tab indicator, in a 48 tall target that closes. */
@Composable
private fun DragHandle(onClose: () -> Unit, modifier: Modifier = Modifier) {
    val label = stringResource(R.string.awrad_action_close_sheet)
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(AwradTheme.sizes.touchTarget)
            .clickable(interactionSource = null, indication = null, role = Role.Button, onClick = onClose)
            .semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .size(width = AwradTheme.spacing.xl3, height = AwradTheme.sizes.tabIndicatorHeight)
                .background(AwradTheme.colors.outline, AwradTheme.shapes.tabIndicator),
        )
    }
}

/**
 * Where the sheet is: [position] is how far it sits below open in px (negative when pulled up past open);
 * [fade] is its opacity under reduced motion. One animation runs at a time ([run]); a drag stops it.
 */
@Stable
private class SheetState {
    var position by mutableFloatStateOf(0f)
    var height by mutableIntStateOf(0)
    var areaHeight by mutableIntStateOf(0)
    var isShown by mutableStateOf(false)
    val fade = Animatable(0f)
    private var running: Job? = null

    /** How much of the scrim shows: with the sheet's position, or its fade under reduced motion. */
    fun visibility(motion: AwradMotion): Float = when {
        !isShown -> 0f
        motion.isReduced -> fade.value
        height == 0 -> 0f
        else -> (1f - position / height).coerceIn(0f, 1f)
    }

    fun run(scope: CoroutineScope, block: suspend () -> Unit) {
        running?.cancel()
        running = scope.launch { block() }
    }

    fun stop() {
        running?.cancel()
    }

    suspend fun open(motion: AwradMotion, velocity: Float = 0f, fromHidden: Boolean = false) {
        if (fromHidden) {
            position = if (motion.isReduced) 0f else height.toFloat()
            isShown = true
        }
        if (motion.isReduced) {
            position = 0f
            fade.animateTo(1f, motion.crossfade())
        } else {
            fade.snapTo(1f)
            animate(position, 0f, velocity, motion.sheet.settle) { value, _ -> position = value }
        }
    }

    suspend fun close(motion: AwradMotion, velocity: Float) {
        if (motion.isReduced) {
            fade.animateTo(0f, motion.crossfade())
        } else {
            animate(position, height.toFloat(), velocity, motion.sheet.settle) { value, _ -> position = value }
        }
    }
}
