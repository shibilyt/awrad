package app.awrad.core.designsystem.theme

import androidx.compose.material3.ColorScheme

/*
 * Material reads colours from a ColorScheme; this fills every slot from the shared roles, so no Material
 * default (or dynamic colour) can show through. Roles Material lacks (surfaceBar, outlineStrong, accent,
 * progress) are on AwradTheme.colors only; the components in `component/` use them where Material would
 * pick the wrong slot (field and outlined-button borders, text buttons, progress indicators).
 *
 * [inverse] is the other theme: inverse slots (snackbars) look like it, so their contrast is the contract's.
 */
internal fun colorSchemeOf(colors: AwradColors, inverse: AwradColors): ColorScheme = ColorScheme(
    primary = colors.primary,
    onPrimary = colors.onPrimary,
    primaryContainer = colors.primaryContainer,
    onPrimaryContainer = colors.onPrimaryContainer,
    inversePrimary = inverse.accent,
    // One brand colour: Material's secondary and tertiary slots (navigation bar pill, tonal buttons,
    // chips) are the same selected-state roles as primary.
    secondary = colors.primary,
    onSecondary = colors.onPrimary,
    secondaryContainer = colors.primaryContainer,
    onSecondaryContainer = colors.onPrimaryContainer,
    tertiary = colors.primary,
    onTertiary = colors.onPrimary,
    tertiaryContainer = colors.primaryContainer,
    onTertiaryContainer = colors.onPrimaryContainer,
    background = colors.background,
    onBackground = colors.onSurface,
    surface = colors.surface,
    onSurface = colors.onSurface,
    surfaceVariant = colors.surface,
    onSurfaceVariant = colors.onSurfaceVariant,
    // Tinting a surface with itself turns Material's tonal elevation off: surfaces stay on the palette.
    surfaceTint = colors.surface,
    inverseSurface = inverse.background,
    inverseOnSurface = inverse.onSurface,
    error = colors.error,
    onError = colors.onError,
    errorContainer = colors.error,
    onErrorContainer = colors.onError,
    outline = colors.outline,
    outlineVariant = colors.outline,
    // The darker of surface and text: black in both themes (light text, dark cards).
    scrim = colors.scrim,
    surfaceBright = colors.surfaceBar,
    surfaceDim = colors.surface,
    // Filled cards and filled fields are surfaces; sheets, menus, the navigation bar and dialogs are bars.
    surfaceContainerLowest = colors.background,
    surfaceContainerLow = colors.surfaceBar,
    surfaceContainer = colors.surfaceBar,
    surfaceContainerHigh = colors.surfaceBar,
    surfaceContainerHighest = colors.surface,
)
