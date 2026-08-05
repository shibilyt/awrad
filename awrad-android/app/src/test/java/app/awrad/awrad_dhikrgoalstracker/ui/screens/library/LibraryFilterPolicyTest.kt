package app.awrad.awrad_dhikrgoalstracker.ui.screens.library

import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class LibraryFilterPolicyTest {

    private val matching = sample(
        title = "Night protection",
        category = DhikrCategory.PROTECTION,
        isCustom = true,
    )
    private val wrongCategory = sample(
        title = "Night family",
        category = DhikrCategory.GENERAL,
        isCustom = true,
    )
    private val builtIn = sample(
        title = "Night protection",
        category = DhikrCategory.PROTECTION,
        isCustom = false,
    )
    private val noSearchHit = sample(
        title = "Morning shield",
        category = DhikrCategory.PROTECTION,
        isCustom = true,
    )

    @Test
    fun featuredCollectionWithSearchAndCustomScope() {
        val filtered = LibraryFilterPolicy.filter(
            items = listOf(matching, wrongCategory, builtIn, noSearchHit),
            query = "night",
            category = DhikrCategory.PROTECTION,
            customOnly = true,
        )
        assertEquals(listOf(matching), filtered)
    }

    @Test
    fun searchMatchesTitleAndArabicFields() {
        val tagged = sample(
            title = "Quiet dhikr",
            category = DhikrCategory.GENERAL,
            isCustom = false,
        )
        val filtered = LibraryFilterPolicy.filter(
            items = listOf(tagged, matching),
            query = "quiet",
            category = null,
            customOnly = false,
        )
        assertEquals(listOf(tagged), filtered)
    }

    @Test
    fun yourDhikrsAndFeaturedCategoryCombineUnderAndSemantics() {
        val filtered = LibraryFilterPolicy.filter(
            items = listOf(matching, wrongCategory, builtIn),
            query = "",
            category = DhikrCategory.PROTECTION,
            customOnly = true,
        )
        assertEquals(listOf(matching), filtered)
    }

    @Test
    fun clearFiltersResetsCategorySearchAndCustomScope() {
        val criteria = LibraryFilterCriteria(
            query = "night",
            category = DhikrCategory.PROTECTION,
            customOnly = true,
        )
        assertTrue(criteria.hasActiveFilters)
        assertEquals(LibraryFilterCriteria(), criteria.cleared())
    }

    private fun sample(
        title: String,
        category: DhikrCategory,
        isCustom: Boolean,
    ) = LibraryFilterItem(
        dhikr = Dhikr(
            title = title,
            arabic = "نص",
            transliteration = title,
            translation = title,
            audioUrl = null,
            audioFileName = null,
            category = category,
            isCustom = isCustom,
        ),
    )
}
