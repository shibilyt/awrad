// Generated from contracts/design-tokens/v1/motion.json. Don't edit by hand:
// regenerate with `./gradlew :core:designsystem:generateAwradTokens`. `verifyAwradTokens` fails the
// build when this file and the contract differ.
@file:Suppress("MagicNumber")

package app.awrad.core.designsystem.theme

import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.Easing
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/** Easings, as cubic-bezier control points. */
public object AwradEasing {
    /** `emphasized`: (0.2, 0, 0, 1). */
    public val emphasized: Easing = CubicBezierEasing(0.2f, 0f, 0f, 1f)

    /** `decelerate`: (0.05, 0.7, 0.1, 1). */
    public val decelerate: Easing = CubicBezierEasing(0.05f, 0.7f, 0.1f, 1f)

    /** `accelerate`: (0.3, 0, 0.8, 0.15). */
    public val accelerate: Easing = CubicBezierEasing(0.3f, 0f, 0.8f, 0.15f)
}

/** Durations in milliseconds. */
public object AwradDurations {
    public const val fade: Int = 100
    public const val color: Int = 150
    public const val short: Int = 250
    public const val medium: Int = 300
    public const val page: Int = 350
    public const val long: Int = 450
}

/** Springs (dampingRatio, stiffness, mass 1). `AwradSpring.spec()` makes the Compose `spring()`. */
public object AwradSprings {
    /** Anything that moves or changes size. */
    public val spatial: AwradSpring = AwradSpring(dampingRatio = 0.8f, stiffness = 380f)

    /** Small, quick movements: press release. */
    public val spatialFast: AwradSpring = AwradSpring(dampingRatio = 0.6f, stiffness = 800f)

    /** Large, heavy movements. */
    public val spatialSlow: AwradSpring = AwradSpring(dampingRatio = 0.8f, stiffness = 200f)

    /** Colour and opacity; never bounces. */
    public val effects: AwradSpring = AwradSpring(dampingRatio = 1f, stiffness = 1600f)

    /** Small pops: selected icon, count tap. */
    public val bouncy: AwradSpring = AwradSpring(dampingRatio = 0.5f, stiffness = 1500f)

    /** Soft entrances: the nav pill appearing. */
    public val bouncySoft: AwradSpring = AwradSpring(dampingRatio = 0.5f, stiffness = 200f)
}

/** Haptic feedback by meaning. `AwradHaptics` performs them. */
public enum class AwradHaptic {
    /** Each count tap, tab and step changes. */
    Tick,

    /** Crossing a threshold: a drag past its release point. */
    Threshold,

    /** Reaching a target. */
    Success,
}

/** The named motions Android uses, and reduced motion. `AwradMotion` turns them into specs. */
public object AwradMotions {
    /** Opening a page. iOS uses the native push. */
    public object PagePush {
        public object Enter {
            public const val scaleFrom: Float = 0.96f
            public const val fadeFrom: Float = 0.35f
        }

        public object Exit {
            public const val scaleTo: Float = 0.985f
        }

        public const val durationMillis: Int = AwradDurations.page
        public val easing: Easing = AwradEasing.emphasized
    }

    /** Going back. Follows predictive back on Android. */
    public object PagePop {
        public object Enter {
            public const val scaleFrom: Float = 0.985f
            public const val fadeFrom: Float = 0.6f
        }

        public object Exit {
            public const val scaleTo: Float = 0.96f
            public const val fadeDurationMillis: Int = AwradDurations.short
        }

        public const val durationMillis: Int = AwradDurations.page
        public val easing: Easing = AwradEasing.emphasized
    }

    /** The page behind a push rounds its corners and dims. */
    public object ScreenDepth {
        public val radius: Dp = AwradRadius.xl3
        public const val dim: Float = 0.34f
        public const val durationMillis: Int = AwradDurations.page
        public val easing: Easing = AwradEasing.emphasized
    }

    /** Switching bottom-navigation tabs. */
    public object TabSwitch {
        public object Enter {
            public const val scaleFrom: Float = 0.985f
            public const val fadeFrom: Float = 0.4f
        }

        public object Exit {
            public const val scaleTo: Float = 1.01f
        }

        public const val durationMillis: Int = AwradDurations.medium
        public val easing: Easing = AwradEasing.emphasized
    }

    /** The selected tab's pill and icon. */
    public object NavPill {
        public const val pillScaleFrom: Float = 0.7f
        public val pillSpring: AwradSpring = AwradSprings.bouncySoft
        public const val iconScale: Float = 1.1f
        public val iconSpring: AwradSpring = AwradSprings.bouncy
        public const val colorDurationMillis: Int = AwradDurations.color
    }

    /** Pressing a card or button. */
    public object Press {
        public const val cardScale: Float = 0.985f
        public const val buttonScale: Float = 0.98f
        public const val pressDurationMillis: Int = AwradDurations.fade
        public val releaseSpring: AwradSpring = AwradSprings.spatialFast
    }

    /** Each count; the number rolls to its next value. */
    public object CountTap {
        public const val popScale: Float = 1.04f
        public val spring: AwradSpring = AwradSprings.bouncy
        public val haptic: AwradHaptic = AwradHaptic.Tick
        public const val numberTransition: String = "roll"
    }

    /** Reaching the target. */
    public object CountComplete {
        public val haptic: AwradHaptic = AwradHaptic.Success
        public val ringSpring: AwradSpring = AwradSprings.spatialSlow
    }

    /** Progress rings and bars changing value. */
    public object RingFill {
        public val spring: AwradSpring = AwradSprings.spatial
    }

    /** Bottom sheets follow the finger and settle with the fling's velocity; corners reach 0 at full height. */
    public object Sheet {
        public val settleSpring: AwradSpring = AwradSprings.spatial
        public const val overshootScale: Float = 1.03f
        public val radius: Dp = AwradRadius.xl3
        public const val releaseVelocity: Float = 150f
    }

    /** Expanding and collapsing a section. */
    public object Expand {
        public val sizeSpring: AwradSpring = AwradSprings.spatial
        public val fadeSpring: AwradSpring = AwradSprings.effects
        public const val chevronRotation: Float = 180f
    }

    /** Items appearing in a list. */
    public object ListAppear {
        public val offset: Dp = 8.dp
        public const val durationMillis: Int = AwradDurations.short
        public val easing: Easing = AwradEasing.decelerate
        public const val staggerMillis: Int = 40
        public const val maxStaggered: Int = 6
    }

    /** Swapping text or status in place. */
    public object ContentSwap {
        public const val fadeInMillis: Int = AwradDurations.color
        public const val fadeOutMillis: Int = AwradDurations.fade
    }

    /**
     * When the system asks for reduced motion, every movement, scale and spring becomes a cross-fade of
     * this duration. Haptics stay.
     */
    public object ReducedMotion {
        /** A cross-fade of this duration replaces every movement, scale and spring. */
        public const val durationMillis: Int = AwradDurations.color
    }
}
