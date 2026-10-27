package app.awrad.core.designsystem.motion

import android.os.Build
import androidx.compose.animation.AnimatedContentTransitionScope
import androidx.compose.animation.AnimatedVisibilityScope
import androidx.compose.animation.EnterExitState
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.FiniteAnimationSpec
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.ProvidableCompositionLocal
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.graphicsLayer
import app.awrad.core.designsystem.theme.AwradMotions.ScreenDepth
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.core.designsystem.theme.SmoothCornerShape

/**
 * The page transitions of one `NavHost` (`pagePush`, `pagePop`), plus what [AwradPage] needs for `screenDepth`:
 * which page went behind and which is coming back. Pass its four functions to the `NavHost`, and provide it with
 * [LocalAwradPageTransitions] around it:
 *
 * ```
 * val pages = rememberAwradPageTransitions()
 * CompositionLocalProvider(LocalAwradPageTransitions provides pages) {
 *     NavHost(…, enterTransition = { pages.enter(this) }, exitTransition = { pages.exit(this) },
 *         popEnterTransition = { pages.popEnter(this) }, popExitTransition = { pages.popExit(this) }) { … }
 * }
 * ```
 *
 * Predictive back works through the same functions: Navigation seeks the pop transition with the gesture, and the
 * screen-depth animation is part of that transition, so it follows the finger too.
 */
@Stable
public class AwradPageTransitions internal constructor(private val motion: AwradMotion) {

    private enum class Role { Entering, Covered, Leaving, Revealed }

    /**
     * Each page's part in the latest transition, keyed by its back-stack entry. Written while the transition is
     * set up, which Compose does in that page's composition before its content, so [AwradPage] normally reads it
     * after; it's snapshot state, so a page that read it earlier recomposes with its new part.
     */
    private val roles = mutableStateMapOf<Any, Role>()

    /** A push: the new page comes in. */
    public fun <S : Any> enter(scope: AnimatedContentTransitionScope<S>): EnterTransition {
        push(scope)
        return motion.pagePushEnter
    }

    /** A push: the current page goes behind. */
    public fun <S : Any> exit(scope: AnimatedContentTransitionScope<S>): ExitTransition {
        push(scope)
        return motion.pagePushExit
    }

    /** A pop (or a predictive-back gesture): the page behind comes back. */
    public fun <S : Any> popEnter(scope: AnimatedContentTransitionScope<S>): EnterTransition {
        pop(scope)
        return motion.pagePopEnter
    }

    /** A pop (or a predictive-back gesture): the current page leaves. */
    public fun <S : Any> popExit(scope: AnimatedContentTransitionScope<S>): ExitTransition {
        pop(scope)
        return motion.pagePopExit
    }

    private fun <S : Any> push(scope: AnimatedContentTransitionScope<S>) = push(scope.initialState, scope.targetState)

    private fun <S : Any> pop(scope: AnimatedContentTransitionScope<S>) = pop(scope.initialState, scope.targetState)

    /** [from] goes behind [to]. */
    internal fun push(from: Any, to: Any) {
        roles[from] = Role.Covered
        roles[to] = Role.Entering
    }

    /** [from] leaves, revealing [to] behind it. */
    internal fun pop(from: Any, to: Any) {
        roles[from] = Role.Leaving
        roles[to] = Role.Revealed
    }

    /** 1 when the page [key] is fully behind another (rounded and dimmed), 0 when it's the page in front. */
    internal fun depth(key: Any, state: EnterExitState): Float = when {
        motion.isReduced -> 0f
        state == EnterExitState.PreEnter && roles[key] == Role.Revealed -> 1f
        state == EnterExitState.PostExit && roles[key] == Role.Covered -> 1f
        else -> 0f
    }

    internal val depthSpec: FiniteAnimationSpec<Float> = tween(ScreenDepth.durationMillis, easing = ScreenDepth.easing)

    internal fun forget(key: Any) {
        roles.remove(key)
    }
}

/** The page transitions for the current motion setting; remember one per `NavHost`. */
@Composable
public fun rememberAwradPageTransitions(): AwradPageTransitions {
    val motion = AwradTheme.motion
    return remember(motion) { AwradPageTransitions(motion) }
}

/** The page transitions of the `NavHost` around; [AwradPage] reads them. Without one, pages get no depth. */
public val LocalAwradPageTransitions: ProvidableCompositionLocal<AwradPageTransitions> =
    staticCompositionLocalOf { AwradPageTransitions(AwradMotion(isReduced = false)) }

/**
 * A `NavHost` destination's content with the `screenDepth` effect: while another page is pushed over it (or it
 * comes back from behind one), it rounds to the `screenDepth` radius and dims by `screenDepth.dim`, in step with
 * the page transition. Call it with the destination's scope and back-stack entry:
 * `composable<Destination> { entry -> AwradPage(scope = this, key = entry) { … } }`.
 *
 * It costs nothing on a page at rest. While it runs, both values are read in the draw phase only (no
 * recomposition or layout per frame), the dim is one rectangle drawn over the content, and the corners are the
 * page layer's outline clip, which the RenderNode applies without an offscreen buffer: continuous corners on
 * API 33 and later, where any outline can clip; a plain round rect before that, where only round rects can
 * (a continuous outline would fall back to a canvas path clip on every frame). The frozen app instead composited
 * the whole page offscreen for the whole transition.
 */
@Composable
public fun AwradPage(
    scope: AnimatedVisibilityScope,
    key: Any,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    val pages = LocalAwradPageTransitions.current
    val depth by scope.transition.animateFloat(transitionSpec = { pages.depthSpec }, label = "screenDepth") {
        pages.depth(key, it)
    }
    DisposableEffect(pages, key) {
        onDispose { pages.forget(key) }
    }
    val scrim = AwradTheme.colors.scrim.copy(alpha = 1f)
    Box(modifier = modifier.screenDepth(depth = { depth }, scrim = scrim)) {
        content()
    }
}

private fun Modifier.screenDepth(depth: () -> Float, scrim: Color): Modifier = this
    .graphicsLayer {
        val value = depth()
        clip = value > 0f
        shape = if (value > 0f) depthShape(value) else RectangleShape
    }
    .drawWithContent {
        drawContent()
        val value = depth()
        if (value > 0f) drawRect(color = scrim, alpha = ScreenDepth.dim * value)
    }

private fun depthShape(depth: Float): Shape {
    val radius = ScreenDepth.radius * depth
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        SmoothCornerShape(radius)
    } else {
        RoundedCornerShape(radius)
    }
}
