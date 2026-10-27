package app.awrad.core.designsystem.motion

import androidx.compose.animation.ContentTransform
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.SizeTransform
import androidx.compose.animation.core.Easing
import androidx.compose.animation.core.FiniteAnimationSpec
import androidx.compose.animation.core.snap
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.togetherWith
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.unit.IntSize
import app.awrad.core.designsystem.theme.AwradMotions.ContentSwap
import app.awrad.core.designsystem.theme.AwradMotions.Expand
import app.awrad.core.designsystem.theme.AwradMotions.PagePop
import app.awrad.core.designsystem.theme.AwradMotions.PagePush
import app.awrad.core.designsystem.theme.AwradMotions.ReducedMotion
import app.awrad.core.designsystem.theme.AwradMotions.TabSwitch
import app.awrad.core.designsystem.theme.AwradSpring
import app.awrad.core.designsystem.theme.AwradSprings
import androidx.compose.animation.core.tween as composeTween

/**
 * The motion tokens (`motion.json`, generated as `AwradMotions`) as ready-to-use Compose specs, honouring the
 * system's reduced-motion setting: when [isReduced], every movement, scale and spring becomes a cross-fade of
 * `reducedMotion.duration` (haptics stay). Read it through `AwradTheme.motion`; never write a raw `tween(…)` or
 * `spring(…)` outside the design system.
 *
 * The named motions with more parts live in their own files: page transitions and screen depth
 * (`AwradPageTransitions`), press feedback (`Modifier.pressFeedback`), haptics (`rememberAwradHaptics`), and the
 * smaller specs (`navPill`, `countTap`, `ringFill`, `sheet`, `listAppear`, in `MotionSpecs.kt`).
 */
@Immutable
public class AwradMotion internal constructor(public val isReduced: Boolean) {

    /** The reduced-motion cross-fade: `reducedMotion.duration` and `reducedMotion.easing` (linear). */
    public fun <T> crossfade(): FiniteAnimationSpec<T> =
        composeTween(durationMillis = ReducedMotion.durationMillis, easing = ReducedMotion.easing)

    /** [spring] as a Compose spring; under reduced motion, the cross-fade. */
    public fun <T> spring(spring: AwradSpring, visibilityThreshold: T? = null): FiniteAnimationSpec<T> =
        if (isReduced) crossfade() else spring.spec(visibilityThreshold)

    /** A timed animation from the duration and easing tokens; under reduced motion, the cross-fade. */
    public fun <T> tween(durationMillis: Int, easing: Easing, delayMillis: Int = 0): FiniteAnimationSpec<T> =
        if (isReduced) {
            crossfade()
        } else {
            composeTween(durationMillis, delayMillis, easing)
        }

    /** A movement, such as a size change: [AwradSprings.spatial]; under reduced motion it jumps (no movement). */
    public fun <T> movement(spring: AwradSpring = AwradSprings.spatial, visibilityThreshold: T? = null):
        FiniteAnimationSpec<T> = if (isReduced) snap() else spring.spec(visibilityThreshold)

    /** `pagePush`, the page coming in: from 0.96 and 0.35 opacity. */
    public val pagePushEnter: EnterTransition = if (isReduced) {
        fadeIn(crossfade())
    } else {
        scaleIn(page(), initialScale = PagePush.Enter.scaleFrom) + fadeIn(page(), PagePush.Enter.fadeFrom)
    }

    /** `pagePush`, the page going behind: to 0.985 (`AwradPage` rounds and dims it: `screenDepth`). */
    public val pagePushExit: ExitTransition =
        if (isReduced) fadeOut(crossfade()) else scaleOut(page(), targetScale = PagePush.Exit.scaleTo)

    /** `pagePop`, the page behind coming back: from 0.985 and 0.6 opacity. */
    public val pagePopEnter: EnterTransition = if (isReduced) {
        fadeIn(crossfade())
    } else {
        scaleIn(pop(), initialScale = PagePop.Enter.scaleFrom) + fadeIn(pop(), PagePop.Enter.fadeFrom)
    }

    /** `pagePop`, the page leaving: to 0.96, fading out over `short`. */
    public val pagePopExit: ExitTransition = if (isReduced) {
        fadeOut(crossfade())
    } else {
        scaleOut(pop(), targetScale = PagePop.Exit.scaleTo) +
            fadeOut(composeTween(PagePop.Exit.fadeDurationMillis, easing = PagePop.easing))
    }

    /** `tabSwitch`, the new tab: from 0.985 and 0.4 opacity. */
    public val tabSwitchEnter: EnterTransition = if (isReduced) {
        fadeIn(crossfade())
    } else {
        scaleIn(tab(), initialScale = TabSwitch.Enter.scaleFrom) + fadeIn(tab(), TabSwitch.Enter.fadeFrom)
    }

    /** `tabSwitch`, the old tab: to 1.01. */
    public val tabSwitchExit: ExitTransition =
        if (isReduced) fadeOut(crossfade()) else scaleOut(tab(), targetScale = TabSwitch.Exit.scaleTo)

    /** `tabSwitch` for an `AnimatedContent` keyed by the selected tab. */
    public fun tabSwitch(): ContentTransform = tabSwitchEnter togetherWith tabSwitchExit

    /**
     * `contentSwap`, for text or status swapped in place (`AwradContentSwap`): fade in over `color`, out over
     * `fade`, on its `easing` (linear); a change of size follows [AwradSprings.spatial].
     */
    public fun contentSwap(): ContentTransform {
        val enter = fadeIn(if (isReduced) crossfade() else swapFade(ContentSwap.fadeInMillis))
        val exit = fadeOut(if (isReduced) crossfade() else swapFade(ContentSwap.fadeOutMillis))
        val size = SizeTransform(clip = false) { _, _ -> movement(visibilityThreshold = IntSize(1, 1)) }
        return ContentTransform(enter, exit, sizeTransform = size)
    }

    /** `expand`, a section opening (`AwradExpand`): its height on [AwradSprings.spatial], fading in on `effects`. */
    public val expandEnter: EnterTransition = if (isReduced) {
        fadeIn(crossfade())
    } else {
        expandVertically(Expand.sizeSpring.spec(IntSize(1, 1))) + fadeIn(Expand.fadeSpring.spec())
    }

    /** `expand`, a section closing. */
    public val expandExit: ExitTransition = if (isReduced) {
        fadeOut(crossfade())
    } else {
        shrinkVertically(Expand.sizeSpring.spec(IntSize(1, 1))) + fadeOut(Expand.fadeSpring.spec())
    }

    /** `expand`, a chevron's rotation in degrees. Animate it with [movement], so it jumps under reduced motion. */
    public fun chevronRotation(isExpanded: Boolean): Float = if (isExpanded) Expand.chevronRotation else 0f

    private fun <T> page(): FiniteAnimationSpec<T> =
        composeTween(PagePush.durationMillis, easing = PagePush.easing)

    private fun <T> pop(): FiniteAnimationSpec<T> =
        composeTween(PagePop.durationMillis, easing = PagePop.easing)

    private fun <T> tab(): FiniteAnimationSpec<T> =
        composeTween(TabSwitch.durationMillis, easing = TabSwitch.easing)

    private fun <T> swapFade(durationMillis: Int): FiniteAnimationSpec<T> =
        composeTween(durationMillis, easing = ContentSwap.easing)

    override fun equals(other: Any?): Boolean = other is AwradMotion && isReduced == other.isReduced

    override fun hashCode(): Int = isReduced.hashCode()

    override fun toString(): String = "AwradMotion(isReduced=$isReduced)"
}

/** The motion for the current reduced-motion setting; `AwradTheme` provides it. */
internal val LocalAwradMotion = staticCompositionLocalOf { AwradMotion(isReduced = false) }
