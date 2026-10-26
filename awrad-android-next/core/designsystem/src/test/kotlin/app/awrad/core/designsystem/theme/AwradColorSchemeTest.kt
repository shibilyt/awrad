package app.awrad.core.designsystem.theme

import androidx.compose.material3.ColorScheme
import androidx.compose.ui.graphics.Color
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class AwradColorSchemeTest {

    private val light = colorSchemeOf(LightAwradColors, inverse = DarkAwradColors)
    private val dark = colorSchemeOf(DarkAwradColors, inverse = LightAwradColors)

    @Test
    fun everyMaterialSlotIsASharedRole() {
        val roles = (LightAwradColors.roles() + DarkAwradColors.roles()).toSet()
        for ((theme, scheme) in listOf("light" to light, "dark" to dark)) {
            val slots = scheme.slots()
            // Material 3 has 36 colour slots; fewer means the reflection below missed some.
            assertTrue(slots.size >= MATERIAL_SLOTS, "$theme: found only ${slots.size} slots")
            val strays = slots.filterValues { it !in roles }
            assertTrue(strays.isEmpty(), "$theme: slots not from colors.json: ${strays.keys}")
        }
    }

    @Test
    fun rolesMapToTheirMaterialSlots() {
        for ((colors, scheme) in listOf(LightAwradColors to light, DarkAwradColors to dark)) {
            assertEquals(colors.background, scheme.background)
            assertEquals(colors.surface, scheme.surface)
            assertEquals(colors.onSurface, scheme.onSurface)
            assertEquals(colors.onSurface, scheme.onBackground)
            assertEquals(colors.onSurfaceVariant, scheme.onSurfaceVariant)
            assertEquals(colors.outline, scheme.outline)
            assertEquals(colors.outline, scheme.outlineVariant)
            assertEquals(colors.primary, scheme.primary)
            assertEquals(colors.onPrimary, scheme.onPrimary)
            assertEquals(colors.primaryContainer, scheme.primaryContainer)
            assertEquals(colors.onPrimaryContainer, scheme.onPrimaryContainer)
            assertEquals(colors.primaryContainer, scheme.secondaryContainer)
            assertEquals(colors.error, scheme.error)
            assertEquals(colors.onError, scheme.onError)
            assertEquals(colors.surface, scheme.surfaceContainerHighest)
            assertEquals(colors.surfaceBar, scheme.surfaceContainer)
            assertEquals(colors.surfaceBar, scheme.surfaceContainerHigh)
        }
    }

    @Test
    fun scrimIsBlackInBothThemes() {
        assertEquals(Color.Black, light.scrim)
        assertEquals(Color.Black, dark.scrim)
    }

    @Test
    fun alphaIsKept() {
        assertEquals(TRANSLUCENT_ALPHA, LightAwradColors.onSurfaceVariant.alpha, ALPHA_TOLERANCE)
        assertEquals(HALF_ALPHA, DarkAwradColors.outlineStrong.alpha, ALPHA_TOLERANCE)
    }

    private fun AwradColors.roles(): List<Color> = listOf(
        background, surface, surfaceBar, onSurface, onSurfaceVariant, outline, outlineStrong, primary, onPrimary,
        primaryContainer, onPrimaryContainer, accent, progress, error, onError,
    )

    /** Every colour property of [ColorScheme] by name. `Color` is an inline class, so its getters return long. */
    private fun ColorScheme.slots(): Map<String, Color> = ColorScheme::class.java.methods
        .filter { it.name.startsWith("get") && it.parameterCount == 0 }
        .filter { it.returnType == Long::class.javaPrimitiveType }
        .associate { it.name.substringBefore('-') to Color((it.invoke(this) as Long).toULong()) }

    private companion object {
        const val MATERIAL_SLOTS = 36
        const val TRANSLUCENT_ALPHA = 0xA6 / 255f
        const val HALF_ALPHA = 0x80 / 255f
        const val ALPHA_TOLERANCE = 0.001f
    }
}
