package app.awrad.awrad_dhikrgoalstracker.data.model

import kotlinx.serialization.Serializable

/** Stable Quran identity shared by Dhikr goals and Wird segments. */
@Serializable
data class QuranRef(
    val surah: Int,
    val ayahStart: Int,
    val ayahEnd: Int? = null,
) {
    val isValid: Boolean
        get() = surah in 1..114 && ayahStart >= 1 && (ayahEnd == null || ayahEnd >= ayahStart)

    val ayahCount: Int
        get() = ((ayahEnd ?: ayahStart) - ayahStart + 1).coerceAtLeast(0)

    fun displayText(): String =
        if (ayahEnd != null) "Qur'an $surah:$ayahStart-$ayahEnd" else "Qur'an $surah:$ayahStart"
}
