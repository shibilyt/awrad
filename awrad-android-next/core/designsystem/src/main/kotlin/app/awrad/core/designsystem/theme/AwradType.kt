// Generated from contracts/design-tokens/v1/typography.json. Don't edit by hand:
// regenerate with `./gradlew :core:designsystem:generateAwradTokens`. `verifyAwradTokens` fails the
// build when this file and the contract differ.
@file:Suppress("MagicNumber")

package app.awrad.core.designsystem.theme

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/**
 * The named text styles, in the interface font unless a style names its own. Read them through
 * `AwradTheme.type`; Material's `Typography` maps onto them in `AwradTypography`.
 */
public object AwradType {
    /** Screen titles; the Hijri date on Home. 22 on 28, weight 600. */
    public val title: TextStyle = TextStyle(
        fontFamily = InterfaceFontFamily,
        fontWeight = FontWeight.SemiBold,
        fontSize = 22.sp,
        lineHeight = 28.sp,
        letterSpacing = 0.sp,
        lineHeightStyle = AwradLineHeightStyle,
    )

    /** Card headings: Today's goals. 18 on 24, weight 600. */
    public val cardTitle: TextStyle = TextStyle(
        fontFamily = InterfaceFontFamily,
        fontWeight = FontWeight.SemiBold,
        fontSize = 18.sp,
        lineHeight = 24.sp,
        letterSpacing = 0.sp,
        lineHeightStyle = AwradLineHeightStyle,
    )

    /** Row titles: a goal's name. 16 on 22, weight 600. */
    public val rowTitle: TextStyle = TextStyle(
        fontFamily = InterfaceFontFamily,
        fontWeight = FontWeight.SemiBold,
        fontSize = 16.sp,
        lineHeight = 22.sp,
        letterSpacing = 0.sp,
        lineHeightStyle = AwradLineHeightStyle,
    )

    /** Section headings: Featured dhikr collections. 15 on 20, weight 600. */
    public val sectionTitle: TextStyle = TextStyle(
        fontFamily = InterfaceFontFamily,
        fontWeight = FontWeight.SemiBold,
        fontSize = 15.sp,
        lineHeight = 20.sp,
        letterSpacing = 0.sp,
        lineHeightStyle = AwradLineHeightStyle,
    )

    /** Paragraphs and form text. 15 on 22, weight 400. */
    public val body: TextStyle = TextStyle(
        fontFamily = InterfaceFontFamily,
        fontWeight = FontWeight.Normal,
        fontSize = 15.sp,
        lineHeight = 22.sp,
        letterSpacing = 0.sp,
        lineHeightStyle = AwradLineHeightStyle,
    )

    /** Text typed into fields (16 stops iOS Safari zooming in). 16 on 22, weight 400. */
    public val input: TextStyle = TextStyle(
        fontFamily = InterfaceFontFamily,
        fontWeight = FontWeight.Normal,
        fontSize = 16.sp,
        lineHeight = 22.sp,
        letterSpacing = 0.sp,
        lineHeightStyle = AwradLineHeightStyle,
    )

    /** Secondary text: the Gregorian date, Next prayer. 14 on 20, weight 400. */
    public val bodySmall: TextStyle = TextStyle(
        fontFamily = InterfaceFontFamily,
        fontWeight = FontWeight.Normal,
        fontSize = 14.sp,
        lineHeight = 20.sp,
        letterSpacing = 0.sp,
        lineHeightStyle = AwradLineHeightStyle,
    )

    /** Links and small buttons: View all. 14 on 20, weight 500. */
    public val label: TextStyle = TextStyle(
        fontFamily = InterfaceFontFamily,
        fontWeight = FontWeight.Medium,
        fontSize = 14.sp,
        lineHeight = 20.sp,
        letterSpacing = 0.sp,
        lineHeightStyle = AwradLineHeightStyle,
    )

    /** Main buttons. 16 on 22, weight 600. */
    public val button: TextStyle = TextStyle(
        fontFamily = InterfaceFontFamily,
        fontWeight = FontWeight.SemiBold,
        fontSize = 16.sp,
        lineHeight = 22.sp,
        letterSpacing = 0.sp,
        lineHeightStyle = AwradLineHeightStyle,
    )

    /** Streaks, counts, metadata. 12 on 16, weight 500. */
    public val caption: TextStyle = TextStyle(
        fontFamily = InterfaceFontFamily,
        fontWeight = FontWeight.Medium,
        fontSize = 12.sp,
        lineHeight = 16.sp,
        letterSpacing = 0.sp,
        lineHeightStyle = AwradLineHeightStyle,
    )

    /** Bottom navigation labels. 11 on 14, weight 500. */
    public val navLabel: TextStyle = TextStyle(
        fontFamily = InterfaceFontFamily,
        fontWeight = FontWeight.Medium,
        fontSize = 11.sp,
        lineHeight = 14.sp,
        letterSpacing = 0.sp,
        lineHeightStyle = AwradLineHeightStyle,
    )

    /**
     * The counting number. The 64 line height is tighter than the font's natural 70 on purpose. 56 on 64,
     * weight 700, tabular numbers.
     */
    public val counter: TextStyle = TextStyle(
        fontFamily = InterfaceFontFamily,
        fontWeight = FontWeight.Bold,
        fontSize = 56.sp,
        lineHeight = 64.sp,
        letterSpacing = 0.sp,
        lineHeightStyle = AwradLineHeightStyle,
        fontFeatureSettings = "tnum",
    )

    /** Qur'anic and dhikr Arabic text; never interface text. Noto Naskh Arabic, 24 on 44, weight 400. */
    public val quran: TextStyle = TextStyle(
        fontFamily = ArabicScriptFontFamily,
        fontWeight = FontWeight.Normal,
        fontSize = 24.sp,
        lineHeight = 44.sp,
        letterSpacing = 0.sp,
        lineHeightStyle = AwradLineHeightStyle,
    )
}
