package app.awrad.awrad_dhikrgoalstracker.ui.screens.library

import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import org.junit.Assert.assertEquals
import org.junit.Test

class LibraryFeaturedCollectionTest {
    @Test
    fun `collection route values round trip`() {
        LibraryFeaturedCollection.entries.forEach { collection ->
            assertEquals(collection, LibraryFeaturedCollection.fromRouteValue(collection.routeValue))
        }
    }

    @Test
    fun `your dhikrs contains only custom entries`() {
        val catalog = listOf(
            dhikr("Custom", DhikrCategory.GENERAL, isCustom = true),
            dhikr("Built in", DhikrCategory.GENERAL),
        )

        assertEquals(
            listOf("Custom"),
            LibraryFeaturedCollection.YOUR_DHIKRS.dhikrsFrom(catalog).map(Dhikr::title),
        )
    }

    @Test
    fun `daily essentials uses morning when morning dhikrs exist`() {
        val catalog = listOf(
            dhikr("Praise", DhikrCategory.PRAISE),
            dhikr("Morning", DhikrCategory.MORNING),
            dhikr("Quran", DhikrCategory.QURAN),
        )

        assertEquals(
            listOf("Morning"),
            LibraryFeaturedCollection.DAILY_ESSENTIALS.dhikrsFrom(catalog).map(Dhikr::title),
        )
    }

    @Test
    fun `daily essentials falls back to praise forgiveness and quran`() {
        val catalog = listOf(
            dhikr("Praise", DhikrCategory.PRAISE),
            dhikr("Forgiveness", DhikrCategory.FORGIVENESS),
            dhikr("Quran", DhikrCategory.QURAN),
            dhikr("General", DhikrCategory.GENERAL),
        )

        assertEquals(
            listOf("Praise", "Forgiveness", "Quran"),
            LibraryFeaturedCollection.DAILY_ESSENTIALS.dhikrsFrom(catalog).map(Dhikr::title),
        )
    }

    @Test
    fun `dhikrs collection combines praise forgiveness and general`() {
        val catalog = listOf(
            dhikr("Praise", DhikrCategory.PRAISE),
            dhikr("Forgiveness", DhikrCategory.FORGIVENESS),
            dhikr("General", DhikrCategory.GENERAL),
            dhikr("Evening", DhikrCategory.EVENING),
        )

        assertEquals(
            listOf("Praise", "Forgiveness", "General"),
            LibraryFeaturedCollection.DHIKRS.dhikrsFrom(catalog).map(Dhikr::title),
        )
    }

    private fun dhikr(
        title: String,
        category: DhikrCategory,
        isCustom: Boolean = false,
    ) = Dhikr(
        title = title,
        arabic = title,
        transliteration = title,
        translation = title,
        audioUrl = null,
        audioFileName = null,
        category = category,
        isCustom = isCustom,
    )
}
