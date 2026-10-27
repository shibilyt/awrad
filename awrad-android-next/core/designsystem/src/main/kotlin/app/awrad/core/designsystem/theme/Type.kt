package app.awrad.core.designsystem.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
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

/** For Qur'anic and dhikr text in Arabic script. Never for interface text. */
public val ArabicScriptFontFamily: FontFamily = FontFamily(
    Font(R.font.notonaskharabic_regular, FontWeight.Normal),
    Font(R.font.notonaskharabic_medium, FontWeight.Medium),
    Font(R.font.notonaskharabic_semibold, FontWeight.SemiBold),
    Font(R.font.notonaskharabic_bold, FontWeight.Bold),
)

private fun TextStyle.interfaceFont(): TextStyle = copy(fontFamily = InterfaceFontFamily)

internal val AwradTypography: Typography = Typography().run {
    copy(
        displayLarge = displayLarge.interfaceFont(),
        displayMedium = displayMedium.interfaceFont(),
        displaySmall = displaySmall.interfaceFont().copy(fontWeight = FontWeight.Bold),
        headlineLarge = headlineLarge.interfaceFont().copy(fontWeight = FontWeight.SemiBold),
        headlineMedium = headlineMedium.interfaceFont().copy(fontWeight = FontWeight.SemiBold),
        headlineSmall = headlineSmall.interfaceFont().copy(fontWeight = FontWeight.SemiBold),
        titleLarge = titleLarge.interfaceFont().copy(fontWeight = FontWeight.SemiBold),
        titleMedium = titleMedium.interfaceFont(),
        titleSmall = titleSmall.interfaceFont(),
        bodyLarge = bodyLarge.interfaceFont(),
        bodyMedium = bodyMedium.interfaceFont(),
        bodySmall = bodySmall.interfaceFont(),
        labelLarge = labelLarge.interfaceFont(),
        labelMedium = labelMedium.interfaceFont(),
        labelSmall = labelSmall.interfaceFont(),
    )
}
