package app.awrad.core.designsystem.motion

import androidx.compose.animation.ContentTransform
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.SizeTransform
import androidx.compose.animation.core.FiniteAnimationSpec
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.runtime.Immutable
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import app.awrad.core.designsystem.theme.AwradEasing
import app.awrad.core.designsystem.theme.AwradHaptic
import app.awrad.core.designsystem.theme.AwradMotions.CountComplete
import app.awrad.core.designsystem.theme.AwradMotions.CountTap
import app.awrad.core.designsystem.theme.AwradMotions.ListAppear
import app.awrad.core.designsystem.theme.AwradMotions.NavPill
import app.awrad.core.designsystem.theme.AwradMotions.RingFill
import app.awrad.core.designsystem.theme.AwradMotions.SegmentIndicator
import app.awrad.core.designsystem.theme.AwradMotions.Select
import app.awrad.core.designsystem.theme.AwradMotions.Sheet
import app.awrad.core.designsystem.theme.AwradSprings
import kotlin.math.min
import kotlin.math.roundToInt

/*
 * The smaller named motions as ready-to-use specs, for the components that come later (the navigation bar,
 * the counter, progress rings, sheets, lists). Each honours reduced motion like AwradMotion: scales stay at 1 and
 * springs become the cross-fade.
 */

/** Progress-ring threshold: a thousandth of the ring. */
private const val RING_THRESHOLD = 0.001f

/** `navPill`: the selected tab's pill grows in on a soft spring, its icon pops, colours change over `color`. */
@Immutable
public class AwradNavPillMotion internal constructor(private val motion: AwradMotion) {
    /** The pill's scale as it appears, animated to 1 with [pillScale]. */
    public val pillScaleFrom: Float = if (motion.isReduced) 1f else NavPill.pillScaleFrom
    public val pillScale: FiniteAnimationSpec<Float> = motion.spring(NavPill.pillSpring)

    /** The selected icon's scale, animated with [iconScale]. */
    public val selectedIconScale: Float = if (motion.isReduced) 1f else NavPill.iconScale
    public val iconScale: FiniteAnimationSpec<Float> = motion.spring(NavPill.iconSpring)

    /** For the pill's and label's colours: linear (`navPill` names no easing). */
    public fun <T> color(): FiniteAnimationSpec<T> = motion.tween(NavPill.colorDurationMillis, AwradEasing.linear)
}

/** `countTap`: a [haptic] tick, the number rolls to its next value, and the counter pops to [popScale]. */
@Immutable
public class AwradCountTapMotion internal constructor(private val motion: AwradMotion) {
    public val haptic: AwradHaptic = CountTap.haptic
    public val popScale: Float = if (motion.isReduced) 1f else CountTap.popScale
    public val pop: FiniteAnimationSpec<Float> = motion.spring(CountTap.spring)

    /**
     * The roll (`numberTransition: roll`) for an `AnimatedContent` keyed by the count: the new number comes in
     * from below when [isIncreasing], from above otherwise; a cross-fade when reduced.
     */
    public fun roll(isIncreasing: Boolean = true): ContentTransform {
        if (motion.isReduced) return fadeIn(motion.crossfade()) togetherWith fadeOut(motion.crossfade())
        val slide = CountTap.spring.spec(visibilityThreshold = IntOffset(1, 1))
        // Opacity never bounces: the `effects` spring.
        val fade = AwradSprings.effects.spec<Float>()
        val direction = if (isIncreasing) 1 else -1
        val enter = slideInVertically(slide) { height -> direction * height } + fadeIn(fade)
        val exit = slideOutVertically(slide) { height -> -direction * height } + fadeOut(fade)
        return ContentTransform(enter, exit, sizeTransform = SizeTransform(clip = true))
    }
}

/** `countComplete`: a [haptic] success, and the ring settles on [ring]. */
@Immutable
public class AwradCountCompleteMotion internal constructor(motion: AwradMotion) {
    public val haptic: AwradHaptic = CountComplete.haptic
    public val ring: FiniteAnimationSpec<Float> = motion.spring(CountComplete.ringSpring, RING_THRESHOLD)
}

/**
 * `sheet`: a bottom sheet follows the finger and [settle]s with the fling's velocity, overshooting to at most
 * [overshootScale]; its top corners are [radius] and reach 0 at full height. A fling faster than
 * [releaseVelocity] (dp per second) settles in its direction.
 */
@Immutable
public class AwradSheetMotion internal constructor(motion: AwradMotion) {
    public val settle: FiniteAnimationSpec<Float> = motion.spring(Sheet.settleSpring)
    public val overshootScale: Float = if (motion.isReduced) 1f else Sheet.overshootScale
    public val radius: Dp = Sheet.radius
    public val releaseVelocity: Float = Sheet.releaseVelocity
}

public val AwradMotion.navPill: AwradNavPillMotion get() = AwradNavPillMotion(this)

public val AwradMotion.countTap: AwradCountTapMotion get() = AwradCountTapMotion(this)

public val AwradMotion.countComplete: AwradCountCompleteMotion get() = AwradCountCompleteMotion(this)

public val AwradMotion.sheet: AwradSheetMotion get() = AwradSheetMotion(this)

/**
 * `select`: an option row, checkbox or switch cross-fading its colours over `color`, linear. (The tick and the
 * switch thumb move with [AwradMotion.movement].)
 */
public fun <T> AwradMotion.select(): FiniteAnimationSpec<T> = tween(Select.colorDurationMillis, Select.easing)

/**
 * `segmentIndicator`: the selected segmented pill's fill and bar moving to the new pill, on `spatial`; their
 * colours over [segmentColor]. Under reduced motion the move becomes the cross-fade.
 */
public fun <T> AwradMotion.segmentIndicator(visibilityThreshold: T? = null): FiniteAnimationSpec<T> =
    spring(SegmentIndicator.spring, visibilityThreshold)

/** `segmentIndicator`'s colour change: over `color`, linear (it names no easing). */
public fun <T> AwradMotion.segmentColor(): FiniteAnimationSpec<T> =
    tween(SegmentIndicator.colorDurationMillis, AwradEasing.linear)

/** `ringFill`: a progress ring or bar moving to a new value. */
public fun AwradMotion.ringFill(): FiniteAnimationSpec<Float> = spring(RingFill.spring, RING_THRESHOLD)

/**
 * `listAppear`: item [index] of a list rises [ListAppear.offset] and fades in over `short`, decelerating, each
 * item [ListAppear.staggerMillis] after the one before, up to [ListAppear.maxStaggered] items. A cross-fade when
 * reduced.
 */
public fun AwradMotion.listAppear(index: Int, density: Density): EnterTransition {
    if (isReduced) return fadeIn(crossfade())
    val delay = min(index, ListAppear.maxStaggered) * ListAppear.staggerMillis
    val offset = with(density) { ListAppear.offset.toPx() }.roundToInt()
    return slideInVertically(tween(ListAppear.durationMillis, ListAppear.easing, delay)) { offset } +
        fadeIn(tween(ListAppear.durationMillis, ListAppear.easing, delay))
}
