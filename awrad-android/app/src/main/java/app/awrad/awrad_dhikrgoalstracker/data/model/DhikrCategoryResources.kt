package app.awrad.awrad_dhikrgoalstracker.data.model

import androidx.annotation.StringRes
import app.awrad.awrad_dhikrgoalstracker.R

@StringRes
fun DhikrCategory.toStringResId(): Int = when (this) {
    DhikrCategory.MORNING -> R.string.category_morning
    DhikrCategory.EVENING -> R.string.category_evening
    DhikrCategory.AFTER_SALAH -> R.string.category_after_salah
    DhikrCategory.FORGIVENESS -> R.string.category_forgiveness
    DhikrCategory.PRAISE -> R.string.category_praise
    DhikrCategory.PROTECTION -> R.string.category_protection
    DhikrCategory.GENERAL -> R.string.category_general
    DhikrCategory.SWALATHS -> R.string.category_swalaths
    DhikrCategory.ASMA_UL_HUSNA -> R.string.category_asma_ul_husna
    DhikrCategory.RAMADAN -> R.string.category_ramadan
    DhikrCategory.QURAN -> R.string.category_quran
}
