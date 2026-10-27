package app.awrad.core.designsystem.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import app.awrad.core.designsystem.motion.AwradMotion
import app.awrad.core.designsystem.motion.LocalAwradMotion
import app.awrad.core.designsystem.motion.rememberSystemReducedMotion

/**
 * Material's shape slots, mapped onto the shared roles so Material components use them too: extra small is the
 * `xs` radius (menus), small `chip`, medium `button` (and fields), large `card`, extra large `dialog` (dialogs,
 * and sheets' top corners).
 */
internal val AwradMaterialShapes: Shapes = Shapes(
    extraSmall = SmoothCornerShape(AwradRadius.xs),
    small = AwradShapes.chip,
    medium = AwradShapes.button,
    large = AwradShapes.card,
    extraLarge = AwradShapes.dialog,
)

private val LocalAwradColors = staticCompositionLocalOf { LightAwradColors }

private val LocalAwradElevation = staticCompositionLocalOf { AwradElevation(LightAwradColors) }

/**
 * The app theme. Colours are the shared roles (`contracts/design-tokens/v1`), light or dark with the system;
 * there is no dynamic (wallpaper) colour. Motion follows the system's reduced-motion setting unless
 * [reducedMotion] says otherwise (previews and tests).
 */
@Composable
public fun AwradTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    reducedMotion: Boolean = rememberSystemReducedMotion(),
    content: @Composable () -> Unit,
) {
    val colors = if (darkTheme) DarkAwradColors else LightAwradColors
    val inverse = if (darkTheme) LightAwradColors else DarkAwradColors
    val colorScheme = remember(colors) { colorSchemeOf(colors, inverse) }
    val elevation = remember(colors) { AwradElevation(colors) }
    val motion = remember(reducedMotion) { AwradMotion(isReduced = reducedMotion) }
    CompositionLocalProvider(
        LocalAwradColors provides colors,
        LocalAwradElevation provides elevation,
        LocalAwradMotion provides motion,
    ) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = AwradTypography,
            shapes = AwradMaterialShapes,
            content = content,
        )
    }
}

/**
 * Reads the design tokens inside [AwradTheme]. Screens use these by name, never a raw number, radius, stroke,
 * text style, duration or colour (the build rejects literals outside `:core:designsystem`).
 */
public object AwradTheme {
    /**
     * Every colour role, including those Material's `ColorScheme` lacks: `surfaceBar`, `outlineStrong`,
     * `accent` and `progress`.
     */
    public val colors: AwradColors
        @Composable
        @ReadOnlyComposable
        get() = LocalAwradColors.current

    /** The fill for a field or a secondary button here: `surface` on a `background`, `background` on a card. */
    public val fill: Color
        @Composable
        @ReadOnlyComposable
        get() = LocalAwradColors.current.fillOn(LocalAwradContainer.current)

    /**
     * The fill for a secondary control here (secondary button, unselected option row or segmented pill):
     * `secondaryContainer` on the page, `background` on a `surface` area.
     */
    public val secondaryFill: Color
        @Composable
        @ReadOnlyComposable
        get() = LocalAwradColors.current.secondaryFillOn(LocalAwradContainer.current)

    /** Text and icons on [secondaryFill]: `onSecondaryContainer`, or `onSurface` on a `surface` area. */
    public val onSecondaryFill: Color
        @Composable
        @ReadOnlyComposable
        get() = LocalAwradColors.current.onSecondaryFillOn(LocalAwradContainer.current)

    /** How a state changes a control's look: `disabledOpacity`. */
    public val states: AwradStates get() = AwradStates

    /** Corner shapes by role (`card`, `button`, `sheet`…), with continuous corners. */
    public val shapes: AwradShapes get() = AwradShapes

    /** The only line widths the design allows (`fieldError`, `checkbox`). */
    public val strokes: AwradStrokes get() = AwradStrokes

    /** The shadows (`floating`), with this theme's colours: none in dark. Draw one with `Modifier.awradShadow`. */
    public val elevation: AwradElevation
        @Composable
        @ReadOnlyComposable
        get() = LocalAwradElevation.current

    /** Spacing roles (`pageMargin`, `cardPadding`…) and the spacing scale. */
    public val spacing: AwradSpacing get() = AwradSpacing

    /** Standard sizes (`touchTarget`, `control`, `icon`…). */
    public val sizes: AwradSizes get() = AwradSizes

    /** The named text styles (`title`, `body`, `input`, `counter`, `quran`…). */
    public val type: AwradType get() = AwradType

    /** Motion specs for the current reduced-motion setting. */
    public val motion: AwradMotion
        @Composable
        @ReadOnlyComposable
        get() = LocalAwradMotion.current
}
