package app.awrad.awrad_dhikrgoalstracker.ui.theme

import android.app.Activity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

private val LightColorScheme = lightColorScheme(
    primary = SageGreen,
    onPrimary = Color.White,
    primaryContainer = SageGreenContainer,
    onPrimaryContainer = OnSageGreenContainer,
    secondary = SageGreen,
    onSecondary = Color.White,
    secondaryContainer = SageGreenContainer,
    onSecondaryContainer = OnSageGreenContainer,
    tertiary = SageGreenLight,
    onTertiary = Color.White,
    background = SurfaceContainerLight,
    onBackground = Neutral10,
    surface = SurfaceLight,
    onSurface = Neutral10,
    surfaceVariant = SurfaceContainerLight,
    onSurfaceVariant = Neutral40,
    outline = Neutral60,
    outlineVariant = Neutral80,
    error = ErrorLight,
    onError = Color.White,
    errorContainer = ErrorContainerLight,
    onErrorContainer = Color(0xFF410002),
    surfaceContainerLowest = Color(0xFFFDFEFB),
    surfaceContainerLow = SurfaceLight,
    surfaceContainer = SurfaceContainerLight,
    surfaceContainerHigh = Neutral95,
    surfaceContainerHighest = Neutral90,
)

private val DarkColorScheme = darkColorScheme(
    primary = SageGreenLight,
    onPrimary = SageGreenDark,
    primaryContainer = SageGreenDark,
    onPrimaryContainer = SageGreenContainer,
    secondary = SageGreenLight,
    onSecondary = OnSageGreenContainer,
    secondaryContainer = SageGreenDark,
    onSecondaryContainer = SageGreenContainer,
    tertiary = SageGreen,
    onTertiary = Color.White,
    background = SurfaceDark,
    onBackground = Neutral90,
    surface = SurfaceDark,
    onSurface = Neutral90,
    surfaceVariant = SurfaceContainerDark,
    onSurfaceVariant = Neutral70,
    outline = Neutral50,
    outlineVariant = Color(0xFF1F3B31),
    error = ErrorDark,
    onError = Color(0xFF690005),
    errorContainer = ErrorContainerDark,
    onErrorContainer = ErrorDark,
    surfaceContainerLowest = Color(0xFF010403),
    surfaceContainerLow = Color(0xFF06100D),
    surfaceContainer = SurfaceContainerDark,
    surfaceContainerHigh = Color(0xFF101B17),
    surfaceContainerHighest = Color(0xFF17251F),
)

@Composable
fun isAwradDarkTheme(): Boolean =
    MaterialTheme.colorScheme.background.luminance() < 0.2f

@Composable
fun AwradDhikrGoalsTrackerTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme

    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = !darkTheme
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = appTypography,
        shapes = Shapes,
        content = content
    )
}
