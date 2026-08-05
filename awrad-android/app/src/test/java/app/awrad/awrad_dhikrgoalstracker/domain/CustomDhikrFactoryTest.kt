package app.awrad.awrad_dhikrgoalstracker.domain

import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CustomDhikrFactoryTest {
    @Test
    fun createAlwaysSetsIsCustomTrueAndNullCatalogKey() {
        val dhikr = CustomDhikrFactory.create(
            title = "My Tasbih",
            arabic = "سبحان الله",
            transliteration = "",
            translation = "",
            category = DhikrCategory.GENERAL,
        )
        assertTrue(dhikr.isCustom)
        assertNull(dhikr.catalogKey)
        assertEquals("My Tasbih", dhikr.title)
        assertEquals("سبحان الله", dhikr.arabic)
    }

    @Test
    fun titleFallsBackToArabicSnippet() {
        val dhikr = CustomDhikrFactory.create(
            title = "",
            arabic = "abcdefghijklmnopqrstuvwxyz0123456789",
            transliteration = "",
            translation = "",
            category = DhikrCategory.GENERAL,
        )
        assertEquals("abcdefghijklmnopqrstuvwxyz0123", dhikr.title)
    }
}
