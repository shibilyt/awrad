package app.awrad.core.designsystem.theme

import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.LineHeightStyle
import app.awrad.core.designsystem.R

/**
 * The interface font (`contracts/design-tokens/v1/fonts/`): Google Sans Flex with its rounded axis at 100, as
 * static instances. It has Latin glyphs only, so Arabic and Malayalam interface text falls back to the system
 * font glyph by glyph, as in the frozen apps.
 */
internal val InterfaceFontFamily: FontFamily = FontFamily(
    Font(R.font.googlesansflexrounded_regular, FontWeight.Normal),
    Font(R.font.googlesansflexrounded_medium, FontWeight.Medium),
    Font(R.font.googlesansflexrounded_semibold, FontWeight.SemiBold),
    Font(R.font.googlesansflexrounded_bold, FontWeight.Bold),
)

/**
 * Noto Naskh Arabic, for Qur'anic and dhikr text in Arabic script: the `quran` style's own `fontFamily`
 * (`AwradType.quran`). Never for interface text.
 */
public val ArabicScriptFontFamily: FontFamily = FontFamily(
    Font(R.font.notonaskharabic_regular, FontWeight.Normal),
    Font(R.font.notonaskharabic_medium, FontWeight.Medium),
    Font(R.font.notonaskharabic_semibold, FontWeight.SemiBold),
    Font(R.font.notonaskharabic_bold, FontWeight.Bold),
)

/**
 * Line heights from `typography.json` are the whole line: the extra space is split evenly above and below the
 * text, and kept on the first and last line, as on iOS and the web.
 */
internal val AwradLineHeightStyle: LineHeightStyle = LineHeightStyle(
    alignment = LineHeightStyle.Alignment.Center,
    trim = LineHeightStyle.Trim.None,
)
