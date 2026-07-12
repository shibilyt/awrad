package app.awrad.awrad_dhikrgoalstracker.util

import android.content.Context
import app.awrad.awrad_dhikrgoalstracker.R
import dagger.hilt.android.qualifiers.ApplicationContext
import java.time.LocalDate
import javax.inject.Inject
import javax.inject.Singleton

/**
 * One day's remembrance item shown on Home and in notifications.
 *
 * [arabic] is the Arabic verse/hadith text, [translation] its English rendering,
 * [source] the citation (localized), and [showTranslation] whether the translation
 * should be displayed (false in Arabic locale, which shows Arabic only).
 */
data class Remembrance(
    val arabic: String,
    val translation: String,
    val source: String,
    val showTranslation: Boolean,
) {
    /**
     * The line shown in notifications: the translation in translation-showing locales,
     * otherwise the Arabic text (Arabic locale). Falls back to Arabic if translation is blank.
     */
    val notificationText: String
        get() = if (showTranslation && translation.isNotBlank()) translation else arabic
}

/**
 * Provides a deterministic daily remembrance from a fixed content pool of Qur'an verses
 * and hadith about the remembrance of Allah.
 *
 * The same [LocalDate] always yields the same item, so Home and every notification agree
 * on the day's remembrance. Selection is `dayOfYear % poolSize` (see [indexForDate]).
 *
 * The slot tags (any/morning/evening) are retained in [SLOTS] for future scheduling use but
 * are NOT used for selection in this version.
 */
@Singleton
class RemembranceProvider @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private val arabic: Array<String> by lazy {
        context.resources.getStringArray(R.array.remembrance_arabic)
    }
    private val translations: Array<String> by lazy {
        context.resources.getStringArray(R.array.remembrance_translation)
    }
    private val sources: Array<String> by lazy {
        context.resources.getStringArray(R.array.remembrance_source)
    }
    private val showTranslation: Boolean by lazy {
        context.resources.getBoolean(R.bool.remembrance_show_translation)
    }

    /** The day's remembrance for [date]. Same date → same item, everywhere. */
    fun forDate(date: LocalDate): Remembrance {
        val size = arabic.size
        val index = indexForDate(date, size)
        return Remembrance(
            arabic = arabic[index],
            // Translation/source arrays share the pool length; guard defensively.
            translation = translations.getOrElse(index) { "" },
            source = sources.getOrElse(index) { "" },
            showTranslation = showTranslation,
        )
    }

    companion object {
        /**
         * Slot tags for each pool item, index-aligned with the content arrays. Retained for
         * future occasion-aware selection; not consulted by [forDate] in this version.
         */
        val SLOTS: List<String> = listOf(
            "any",      // 1  Ar-Ra'd 13:28
            "any",      // 2  Al-Baqarah 2:152
            "morning",  // 3  Al-Ahzab 33:41–42
            "any",      // 4  Al-'Ankabut 29:45
            "any",      // 5  Aal 'Imran 3:191
            "evening",  // 6  Al-A'raf 7:205
            "any",      // 7  Al-Jumu'ah 62:10
            "any",      // 8  Sahih al-Bukhari 6407
            "any",      // 9  Sahih al-Bukhari 7405
            "morning",  // 10 Jami' at-Tirmidhi 3377
            "any",      // 11 Sahih Muslim 2676
            "any",      // 12 Sahih al-Bukhari 6682
            "any",      // 13 Sahih Muslim 2695
            "any",      // 14 Jami' at-Tirmidhi 3375
        )

        /**
         * Deterministic index into the content pool for [date]. Always in `0 until poolSize`
         * (as long as [poolSize] > 0). Rotates day-to-day via day-of-year.
         */
        fun indexForDate(date: LocalDate, poolSize: Int): Int {
            require(poolSize > 0) { "poolSize must be positive" }
            return date.dayOfYear % poolSize
        }
    }
}
