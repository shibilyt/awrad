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
    val motion = remember(reducedMotion) { AwradMotion(isReduced = reducedMotion) }
    CompositionLocalProvider(LocalAwradColors provides colors, LocalAwradMotion provides motion) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = AwradTypography,
            shapes = AwradMaterialShapes,
            content = content,
        )
    }
}

/**
 * Reads the design tokens inside [AwradTheme]. Screens use these by name, never a raw number, radius, text style,
 * duration or colour (the build rejects literals outside `:core:designsystem`).
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

    /** Corner shapes by role (`card`, `button`, `sheet`…), with continuous corners. */
    public val shapes: AwradShapes get() = AwradShapes

    /** Spacing roles (`pageMargin`, `cardPadding`…) and the spacing scale. */
    public val spacing: AwradSpacing get() = AwradSpacing

    /** Standard sizes (`touchTarget`, `icon`…). */
    public val sizes: AwradSizes get() = AwradSizes

    /** The named text styles (`title`, `body`, `counter`…). */
    public val type: AwradType get() = AwradType

    /** Motion specs for the current reduced-motion setting. */
    public val motion: AwradMotion
        @Composable
        @ReadOnlyComposable
        get() = LocalAwradMotion.current
}
