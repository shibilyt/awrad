package app.awrad.awrad_dhikrgoalstracker.notification

import android.content.Context
import android.content.res.Configuration
import android.os.LocaleList
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import dagger.hilt.android.qualifiers.ApplicationContext
import java.util.Locale
import javax.inject.Inject
import javax.inject.Singleton

/** Resolves the user-visible goal name stored in an urgency notification. */
fun interface NotificationGoalNameResolver {
    fun resolve(dhikr: Dhikr, appLanguage: String): String
}

/**
 * Uses Android string resources as the source of localized built-in notification names.
 *
 * A per-call configuration context respects the selected app language without changing the
 * process-wide configuration. Custom and unmapped dhikrs retain their persisted titles.
 */
@Singleton
class AndroidNotificationGoalNameResolver @Inject constructor(
    @ApplicationContext private val applicationContext: Context,
) : NotificationGoalNameResolver {
    override fun resolve(dhikr: Dhikr, appLanguage: String): String {
        if (dhikr.isCustom) return dhikr.title
        val resourceId = resourceIdFor(dhikr.catalogKey) ?: return dhikr.title
        return applicationContext.localizedResources(appLanguage).getString(resourceId)
    }

    private fun Context.localizedResources(appLanguage: String) =
        createConfigurationContext(
            Configuration(resources.configuration).apply {
                setLocales(LocaleList.forLanguageTags(normalizeLanguage(appLanguage)))
            },
        ).resources

    companion object {
        internal val resourceIdsByCatalogKey = mapOf(
            "surah-ikhlas" to R.string.notif_goal_name_surah_ikhlas,
            "tahleel" to R.string.notif_goal_name_tahleel,
            "ya-wahhabu" to R.string.notif_goal_name_ya_wahhabu,
            "isthighfar" to R.string.notif_goal_name_isthighfar,
            "swalath-al-fathimiyya" to R.string.notif_goal_name_swalath_al_fathimiyya,
            "swalath" to R.string.notif_goal_name_swalath,
            "swalath-sayyidina" to R.string.notif_goal_name_swalath_sayyidina,
            "swalath-al-fatih" to R.string.notif_goal_name_swalath_al_fatih,
            "swalath-al-nariyya" to R.string.notif_goal_name_swalath_al_nariyya,
            "swalath-for-debt" to R.string.notif_goal_name_swalath_for_debt,
            "ramadan-dhikr" to R.string.notif_goal_name_ramadan_dhikr,
            "ramadan-first-ten-nights" to R.string.notif_goal_name_ramadan_first_ten_nights,
            "ramadan-second-ten-nights" to R.string.notif_goal_name_ramadan_second_ten_nights,
        )

        internal fun resourceIdFor(catalogKey: String?): Int? = resourceIdsByCatalogKey[catalogKey]

        fun normalizeLanguage(language: String): String =
            language.trim().lowercase(Locale.ROOT).substringBefore('-').ifBlank { "en" }
    }
}
