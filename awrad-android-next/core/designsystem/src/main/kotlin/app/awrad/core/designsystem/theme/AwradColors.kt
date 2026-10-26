// Generated from contracts/design-tokens/v1/colors.json. Don't edit by hand:
// regenerate with `./gradlew :core:designsystem:generateAwradColors`. `verifyAwradColors` fails the
// build when this file and the contract differ.
@file:Suppress("LongParameterList", "MagicNumber")

package app.awrad.core.designsystem.theme

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color

/**
 * The shared colour roles of one theme. Pick a colour by role, never by hex or by checking the theme:
 * read these through [AwradTheme.colors] (or `MaterialTheme.colorScheme` for the roles Material has).
 */
@Immutable
public class AwradColors internal constructor(
    /** Screen background. */
    public val background: Color,
    /** Cards and grouped content: Today's goals, Next prayer, collections. */
    public val surface: Color,
    /** Bottom navigation, sheets and other bars. */
    public val surfaceBar: Color,
    /** Main text and icons on any background, surface or bar. */
    public val onSurface: Color,
    /** Secondary text: subtitles, counts, labels. */
    public val onSurfaceVariant: Color,
    /** Decorative dividers between rows, and the track of progress rings and bars. */
    public val outline: Color,
    /** Borders that identify a control: text fields, outlined buttons. */
    public val outlineStrong: Color,
    /** Brand fills: main buttons, arrow buttons. */
    public val primary: Color,
    /** Text and icons on primary. */
    public val onPrimary: Color,
    /** Selected state fill: the selected tab pill, selected chips. */
    public val primaryContainer: Color,
    /** Text and icons on primaryContainer. */
    public val onPrimaryContainer: Color,
    /** Accent text and icons on backgrounds and surfaces: streaks, links, the selected tab's label. */
    public val accent: Color,
    /** Goal progress rings and bars. */
    public val progress: Color,
    /** Errors and destructive actions (text, icons, fills). */
    public val error: Color,
    /** Text and icons on an error fill. */
    public val onError: Color,
    /** Dimmed backdrop behind dialogs and sheets. */
    public val scrim: Color,
)

internal val LightAwradColors: AwradColors = AwradColors(
    background = Color(0xFFFFFFFF),
    surface = Color(0xFFE8EDE9),
    surfaceBar = Color(0xFFF9FBFA),
    onSurface = Color(0xFF000000),
    onSurfaceVariant = Color(0xA6000000),
    outline = Color(0x1A000000),
    outlineStrong = Color(0x80000000),
    primary = Color(0xFF23553C),
    onPrimary = Color(0xFFFFFFFF),
    primaryContainer = Color(0xFFB7D6B6),
    onPrimaryContainer = Color(0xFF000000),
    accent = Color(0xFF23553C),
    progress = Color(0xFF23553C),
    error = Color(0xFFB3261E),
    onError = Color(0xFFFFFFFF),
    scrim = Color(0x66000000),
)

internal val DarkAwradColors: AwradColors = AwradColors(
    background = Color(0xFF121412),
    surface = Color(0xFF000000),
    surfaceBar = Color(0xFF313B34),
    onSurface = Color(0xFFE3E5E3),
    onSurfaceVariant = Color(0xA6E3E5E3),
    outline = Color(0xFF313B34),
    outlineStrong = Color(0x80E3E5E3),
    primary = Color(0xFF23553C),
    onPrimary = Color(0xFFFFFFFF),
    primaryContainer = Color(0xFF23553C),
    onPrimaryContainer = Color(0xFFB7D6B6),
    accent = Color(0xFFB7D6B6),
    progress = Color(0xFFE3E5E3),
    error = Color(0xFFF2B8B5),
    onError = Color(0xFF000000),
    scrim = Color(0x66000000),
)
