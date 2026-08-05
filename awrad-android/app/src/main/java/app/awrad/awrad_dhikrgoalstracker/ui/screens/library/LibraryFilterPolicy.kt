package app.awrad.awrad_dhikrgoalstracker.ui.screens.library

import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory

data class LibraryFilterItem(
    val dhikr: Dhikr,
)

data class LibraryFilterCriteria(
    val query: String = "",
    val category: DhikrCategory? = null,
    val customOnly: Boolean = false,
) {
    val hasActiveFilters: Boolean
        get() = query.isNotBlank() || category != null || customOnly

    fun cleared(): LibraryFilterCriteria = LibraryFilterCriteria()
}

object LibraryFilterPolicy {
    fun filter(
        items: List<LibraryFilterItem>,
        query: String,
        category: DhikrCategory?,
        customOnly: Boolean,
    ): List<LibraryFilterItem> {
        val normalizedQuery = query.trim()
        return items.filter { item ->
            val matchesCustom = !customOnly || item.dhikr.isCustom
            val matchesCategory = category == null || item.dhikr.category == category
            val matchesSearch = normalizedQuery.isBlank() || matchesSearch(item, normalizedQuery)
            matchesCustom && matchesCategory && matchesSearch
        }
    }

    private fun matchesSearch(item: LibraryFilterItem, query: String): Boolean {
        val dhikr = item.dhikr
        return dhikr.title.contains(query, ignoreCase = true) ||
            dhikr.transliteration.contains(query, ignoreCase = true) ||
            dhikr.translation.contains(query, ignoreCase = true) ||
            dhikr.arabic.contains(query)
    }
}
