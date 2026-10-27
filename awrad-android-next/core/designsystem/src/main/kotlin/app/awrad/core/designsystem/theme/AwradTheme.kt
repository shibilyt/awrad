package app.awrad.core.designsystem.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

private val AwradShapes = Shapes(
    small = RoundedCornerShape(12.dp),
    medium = RoundedCornerShape(18.dp),
    large = RoundedCornerShape(24.dp),
)

private val LocalAwradColors = staticCompositionLocalOf { LightAwradColors }

/**
 * The app theme. Colours are the shared roles (`contracts/design-tokens/v1`), light or dark with the system;
 * there is no dynamic (wallpaper) colour.
 */
@Composable
public fun AwradTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val colors = if (darkTheme) DarkAwradColors else LightAwradColors
    val inverse = if (darkTheme) LightAwradColors else DarkAwradColors
    val colorScheme = remember(colors) { colorSchemeOf(colors, inverse) }
    CompositionLocalProvider(LocalAwradColors provides colors) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = AwradTypography,
            shapes = AwradShapes,
            content = content,
        )
    }
}

/** Reads the current theme's values inside [AwradTheme]. */
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
}
