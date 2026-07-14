package app.awrad.awrad_dhikrgoalstracker.ui.screens.counting

import org.junit.Assert.assertEquals
import org.junit.Test

class CountingDhikrTextScaleTest {

    @Test
    fun `increase moves through supported text scales and stops at maximum`() {
        assertEquals(1f, nextCountingDhikrTextScale(0.85f))
        assertEquals(1.15f, nextCountingDhikrTextScale(1f))
        assertEquals(1.3f, nextCountingDhikrTextScale(1.15f))
        assertEquals(1.3f, nextCountingDhikrTextScale(1.3f))
    }

    @Test
    fun `decrease moves through supported text scales and stops at minimum`() {
        assertEquals(1.15f, previousCountingDhikrTextScale(1.3f))
        assertEquals(1f, previousCountingDhikrTextScale(1.15f))
        assertEquals(0.85f, previousCountingDhikrTextScale(1f))
        assertEquals(0.85f, previousCountingDhikrTextScale(0.85f))
    }

    @Test
    fun `unknown text scales snap to the nearest step in the requested direction`() {
        assertEquals(1.15f, nextCountingDhikrTextScale(1.02f))
        assertEquals(1f, previousCountingDhikrTextScale(1.02f))
    }

    @Test
    fun `line spacing moves through supported steps and clamps at edges`() {
        assertEquals(1f, nextCountingDhikrLineSpacing(0.9f))
        assertEquals(1.15f, nextCountingDhikrLineSpacing(1f))
        assertEquals(1.3f, nextCountingDhikrLineSpacing(1.15f))
        assertEquals(1.3f, nextCountingDhikrLineSpacing(1.3f))

        assertEquals(1.15f, previousCountingDhikrLineSpacing(1.3f))
        assertEquals(1f, previousCountingDhikrLineSpacing(1.15f))
        assertEquals(0.9f, previousCountingDhikrLineSpacing(1f))
        assertEquals(0.9f, previousCountingDhikrLineSpacing(0.9f))
    }
}
