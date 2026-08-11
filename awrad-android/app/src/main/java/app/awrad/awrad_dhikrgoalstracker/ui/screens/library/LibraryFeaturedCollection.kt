package app.awrad.awrad_dhikrgoalstracker.ui.screens.library

import androidx.annotation.StringRes
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory

enum class LibraryFeaturedCollection(
    val routeValue: String,
    @StringRes val titleRes: Int,
) {
    YOUR_DHIKRS("your-dhikrs", R.string.collection_your_dhikrs),
    ASMA_UL_HUSNA("asma-ul-husna", R.string.category_asma_ul_husna),
    DAILY_ESSENTIALS("daily-essentials", R.string.collection_daily_essentials),
    SWALATHS("swalaths", R.string.collection_swalaths),
    DHIKRS("dhikrs", R.string.collection_dhikrs),
    EVENING_DHIKRS("evening-dhikrs", R.string.collection_evening_dhikrs),
    AFTER_PRAYER("after-prayer", R.string.collection_after_prayer),
    ;

    fun dhikrsFrom(catalog: List<Dhikr>): List<Dhikr> = when (this) {
        YOUR_DHIKRS -> catalog.filter(Dhikr::isCustom)
        ASMA_UL_HUSNA -> catalog.filterCategory(DhikrCategory.ASMA_UL_HUSNA)
        DAILY_ESSENTIALS -> {
            if (catalog.any { it.category == DhikrCategory.MORNING }) {
                catalog.filterCategory(DhikrCategory.MORNING)
            } else {
                catalog.filterCategories(
                    DhikrCategory.PRAISE,
                    DhikrCategory.FORGIVENESS,
                    DhikrCategory.QURAN,
                )
            }
        }
        SWALATHS -> catalog.filterCategory(DhikrCategory.SWALATHS)
        DHIKRS -> catalog.filterCategories(
            DhikrCategory.PRAISE,
            DhikrCategory.FORGIVENESS,
            DhikrCategory.GENERAL,
        )
        EVENING_DHIKRS -> catalog.filterCategory(DhikrCategory.EVENING)
        AFTER_PRAYER -> catalog.filterCategory(DhikrCategory.AFTER_SALAH)
    }

    fun countFrom(
        categoryCounts: Map<DhikrCategory, Int>,
        customCount: Int,
    ): Int = when (this) {
        YOUR_DHIKRS -> customCount
        ASMA_UL_HUSNA -> categoryCounts[DhikrCategory.ASMA_UL_HUSNA] ?: 0
        DAILY_ESSENTIALS -> categoryCounts[DhikrCategory.MORNING]
            ?.takeIf { it > 0 }
            ?: categoryCounts.countFor(
                DhikrCategory.PRAISE,
                DhikrCategory.FORGIVENESS,
                DhikrCategory.QURAN,
            )
        SWALATHS -> categoryCounts[DhikrCategory.SWALATHS] ?: 0
        DHIKRS -> categoryCounts.countFor(
            DhikrCategory.PRAISE,
            DhikrCategory.FORGIVENESS,
            DhikrCategory.GENERAL,
        )
        EVENING_DHIKRS -> categoryCounts[DhikrCategory.EVENING] ?: 0
        AFTER_PRAYER -> categoryCounts[DhikrCategory.AFTER_SALAH] ?: 0
    }

    companion object {
        fun fromRouteValue(value: String?): LibraryFeaturedCollection? =
            entries.firstOrNull { it.routeValue == value }
    }
}

private fun List<Dhikr>.filterCategory(category: DhikrCategory): List<Dhikr> =
    filter { it.category == category }

private fun List<Dhikr>.filterCategories(vararg categories: DhikrCategory): List<Dhikr> =
    filter { it.category in categories }

private fun Map<DhikrCategory, Int>.countFor(vararg categories: DhikrCategory): Int =
    categories.sumOf { this[it] ?: 0 }
