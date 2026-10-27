package app.awrad.core.designsystem.theme

import androidx.compose.ui.text.font.FontListFontFamily
import androidx.compose.ui.text.font.FontStyle
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class AwradTypographyTest {

    private val styles = with(AwradTypography) {
        mapOf(
            "displayLarge" to displayLarge,
            "displayMedium" to displayMedium,
            "displaySmall" to displaySmall,
            "headlineLarge" to headlineLarge,
            "headlineMedium" to headlineMedium,
            "headlineSmall" to headlineSmall,
            "titleLarge" to titleLarge,
            "titleMedium" to titleMedium,
            "titleSmall" to titleSmall,
            "bodyLarge" to bodyLarge,
            "bodyMedium" to bodyMedium,
            "bodySmall" to bodySmall,
            "labelLarge" to labelLarge,
            "labelMedium" to labelMedium,
            "labelSmall" to labelSmall,
        )
    }

    @Test
    fun everyStyleUsesTheInterfaceFont() {
        styles.forEach { (name, style) -> assertEquals(InterfaceFontFamily, style.fontFamily, name) }
    }

    @Test
    fun everyStyleHasABundledWeightSoNothingIsSynthesised() {
        val bundled = (InterfaceFontFamily as FontListFontFamily).fonts.map { it.weight to it.style }.toSet()
        styles.forEach { (name, style) ->
            val weight = checkNotNull(style.fontWeight) { "$name has no weight" }
            assertTrue(weight to (style.fontStyle ?: FontStyle.Normal) in bundled, "$name: $weight isn't bundled")
        }
    }
}
