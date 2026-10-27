// Generated from contracts/design-tokens/v1/shape.json. Don't edit by hand:
// regenerate with `./gradlew :core:designsystem:generateAwradTokens`. `verifyAwradTokens` fails the
// build when this file and the contract differ.
@file:Suppress("MagicNumber")

package app.awrad.core.designsystem.theme

import androidx.compose.runtime.Immutable
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/** The corner-radius scale (without `full`). Screens use a role from [AwradShapes], not these. */
public object AwradRadius {
    /** 2 */
    public val xxxs: Dp = 2.dp

    /** 4 */
    public val xxs: Dp = 4.dp

    /** 8 */
    public val xs: Dp = 8.dp

    /** 12 */
    public val sm: Dp = 12.dp

    /** 16 */
    public val md: Dp = 16.dp

    /** 20 */
    public val lg: Dp = 20.dp

    /** 24 */
    public val xl: Dp = 24.dp

    /** 28 */
    public val xl2: Dp = 28.dp

    /** 32 */
    public val xl3: Dp = 32.dp
}

/**
 * Corner shapes by role, with continuous corners. Read them through `AwradTheme.shapes`;
 * Material's `Shapes` map onto them in `AwradTheme`.
 */
public object AwradShapes {
    /** Cards and grouped content: `xl`, 24. */
    public val card: SmoothCornerShape = SmoothCornerShape(AwradRadius.xl, CornerSmoothing)

    /** Small tiles, such as collection tiles: `md`, 16. */
    public val tile: SmoothCornerShape = SmoothCornerShape(AwradRadius.md, CornerSmoothing)

    /** Buttons: `md`, 16. */
    public val button: SmoothCornerShape = SmoothCornerShape(AwradRadius.md, CornerSmoothing)

    /** Text fields: `md`, 16. */
    public val field: SmoothCornerShape = SmoothCornerShape(AwradRadius.md, CornerSmoothing)

    /** Chips, pills, tags: fully rounded. */
    public val chip: SmoothCornerShape = SmoothCornerShape.full(CornerSmoothing)

    /** Circular icon buttons: fully rounded. */
    public val roundButton: SmoothCornerShape = SmoothCornerShape.full(CornerSmoothing)

    /** The floating bottom navigation bar: `xl2`, 28. */
    public val navBar: SmoothCornerShape = SmoothCornerShape(AwradRadius.xl2, CornerSmoothing)

    /** The selected-tab indicator: fully rounded. */
    public val navPill: SmoothCornerShape = SmoothCornerShape.full(CornerSmoothing)

    /** Top corners of bottom sheets: `xl3`, 32. */
    public val sheet: SmoothCornerShape = SmoothCornerShape(AwradRadius.xl3, CornerSmoothing)

    /** Dialogs: `xl3`, 32. */
    public val dialog: SmoothCornerShape = SmoothCornerShape(AwradRadius.xl3, CornerSmoothing)

    /** The screen behind a pushed page: `xl3`, 32. */
    public val screenDepth: SmoothCornerShape = SmoothCornerShape(AwradRadius.xl3, CornerSmoothing)

    /** A checkbox's box (the only use of 4): `xxs`, 4. */
    public val checkbox: SmoothCornerShape = SmoothCornerShape(AwradRadius.xxs, CornerSmoothing)

    /** Squares in the onboarding step indicator: `xxxs`, 2. */
    public val stepDot: SmoothCornerShape = SmoothCornerShape(AwradRadius.xxxs, CornerSmoothing)

    /** The bar under the selected segmented pill: fully rounded. */
    public val tabIndicator: SmoothCornerShape = SmoothCornerShape.full(CornerSmoothing)

    /** Top corners of the content area under a large-title header (My Goals): `xl3`, 32. */
    public val contentSheet: SmoothCornerShape = SmoothCornerShape(AwradRadius.xl3, CornerSmoothing)
}

/**
 * Line widths: every line the design allows, since it's built from filled shapes. Read them through
 * `AwradTheme.strokes`.
 */
public object AwradStrokes {
    /** Border of a field in error, always with its message: 1.5. */
    public val fieldError: Dp = 1.5.dp

    /** An unticked checkbox's box, in outlineStrong: 2. */
    public val checkbox: Dp = 2.dp

    /** Keyboard focus ring on the web, in accent: 2. */
    public val focusRing: Dp = 2.dp

    /** How far `focusRing` is drawn outside the element's edge: 2. */
    public val focusRingOffset: Dp = 2.dp
}

/**
 * Elevation: the only shadows the design allows, with one theme's colours. Read them through
 * `AwradTheme.elevation` and draw one with `Modifier.awradShadow`.
 */
@Immutable
public class AwradElevation internal constructor(colors: AwradColors) {
    /** Floating elements over content: the bottom bar. The only shadow; dark mode has none. y 4, blur 16, `shadow`. */
    public val floating: AwradShadow = AwradShadow(y = 4.dp, blur = 16.dp, color = colors.shadow)
}

/** `corners: continuous`. */
private const val CornerSmoothing: Float = SmoothCornerShape.CONTINUOUS
