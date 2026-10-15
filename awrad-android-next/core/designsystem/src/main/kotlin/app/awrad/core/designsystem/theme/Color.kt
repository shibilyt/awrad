package app.awrad.core.designsystem.theme

import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.graphics.Color

private val SageGreen = Color(0xFF4B7C5A)
private val SageGreenLight = Color(0xFF6B9E7A)
private val SageGreenDark = Color(0xFF2E5C3D)
private val SageGreenContainer = Color(0xFFD4E8DA)
private val OnSageGreenContainer = Color(0xFF1A3D26)

private val Neutral10 = Color(0xFF1A1C1A)
private val Neutral20 = Color(0xFF2F312F)
private val Neutral30 = Color(0xFF454745)
private val Neutral40 = Color(0xFF5D5F5D)
private val Neutral50 = Color(0xFF767876)
private val Neutral60 = Color(0xFF909290)
private val Neutral70 = Color(0xFFABADAB)
private val Neutral80 = Color(0xFFC7C9C7)
private val Neutral90 = Color(0xFFE3E5E3)
private val Neutral95 = Color(0xFFF1F3F1)

private val SurfaceLight = Color(0xFFFFFFFF)
private val SurfaceDark = Color(0xFF121412)
private val SurfaceContainerLight = Color(0xFFF0F2F0)
private val SurfaceContainerDark = Color(0xFF1E201E)

/*
 * The palette is private: screens read roles from MaterialTheme.colorScheme
 * (primary = the sage accent, primaryContainer = its tint) and never pick a
 * colour by checking whether the theme is dark.
 */
internal val LightColors = lightColorScheme(
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
    error = Color(0xFFBA1A1A),
    onError = Color.White,
    errorContainer = Color(0xFFFFDAD6),
    onErrorContainer = Color(0xFF410002),
    surfaceContainerLowest = Color(0xFFFDFEFB),
    surfaceContainerLow = SurfaceLight,
    surfaceContainer = SurfaceContainerLight,
    surfaceContainerHigh = Neutral95,
    surfaceContainerHighest = Neutral90,
)

internal val DarkColors = darkColorScheme(
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
    outlineVariant = Neutral30,
    error = Color(0xFFFFB4AB),
    onError = Color(0xFF690005),
    errorContainer = Color(0xFF93000A),
    onErrorContainer = Color(0xFFFFB4AB),
    surfaceContainerLowest = Color(0xFF0E100E),
    surfaceContainerLow = Color(0xFF181A18),
    surfaceContainer = SurfaceContainerDark,
    surfaceContainerHigh = Color(0xFF282A28),
    surfaceContainerHighest = Neutral20,
)
