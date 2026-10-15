package app.awrad.core.designsystem.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import app.awrad.core.designsystem.R

private val Manrope = FontFamily(
    Font(R.font.manrope_regular, FontWeight.Normal),
    Font(R.font.manrope_medium, FontWeight.Medium),
    Font(R.font.manrope_semibold, FontWeight.SemiBold),
    Font(R.font.manrope_bold, FontWeight.Bold),
)

/** For Qur'anic and dhikr text in Arabic script. */
public val ArabicScriptFontFamily: FontFamily = FontFamily(
    Font(R.font.notonaskharabic_regular, FontWeight.Normal),
    Font(R.font.notonaskharabic_medium, FontWeight.Medium),
    Font(R.font.notonaskharabic_semibold, FontWeight.SemiBold),
    Font(R.font.notonaskharabic_bold, FontWeight.Bold),
)

private fun TextStyle.manrope(): TextStyle = copy(fontFamily = Manrope)

internal val AwradTypography: Typography = Typography().run {
    copy(
        displayLarge = displayLarge.manrope(),
        displayMedium = displayMedium.manrope(),
        displaySmall = displaySmall.manrope().copy(fontWeight = FontWeight.Bold),
        headlineLarge = headlineLarge.manrope().copy(fontWeight = FontWeight.SemiBold),
        headlineMedium = headlineMedium.manrope().copy(fontWeight = FontWeight.SemiBold),
        headlineSmall = headlineSmall.manrope().copy(fontWeight = FontWeight.SemiBold),
        titleLarge = titleLarge.manrope().copy(fontWeight = FontWeight.SemiBold),
        titleMedium = titleMedium.manrope(),
        titleSmall = titleSmall.manrope(),
        bodyLarge = bodyLarge.manrope(),
        bodyMedium = bodyMedium.manrope(),
        bodySmall = bodySmall.manrope(),
        labelLarge = labelLarge.manrope(),
        labelMedium = labelMedium.manrope(),
        labelSmall = labelSmall.manrope(),
    )
}
