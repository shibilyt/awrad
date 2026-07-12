package app.awrad.awrad_dhikrgoalstracker.ui.screens.onboarding

import java.time.LocalTime

/**
 * The four dhikr-reminder moments offered during onboarding. Prayer-anchored
 * presets resolve against the user's actual prayer times when a location is
 * set; otherwise they fall back to a sensible fixed hour. Either way the
 * result is stored as a plain fixed-time goal reminder the user can edit
 * later from the goal's reminder screen.
 */
enum class OnboardingReminderPreset {
    AFTER_FAJR,
    MORNING,
    AFTER_ASR,
    AFTER_MAGHRIB,
}

object OnboardingReminderTimes {
    /** "After Fajr/Asr" presets land this long after the prayer time. */
    const val PRAYER_OFFSET_MINUTES = 30L

    /** Maghrib adhkar are recited soon after the prayer, so a shorter gap. */
    const val MAGHRIB_OFFSET_MINUTES = 15L

    val FALLBACK_AFTER_FAJR: LocalTime = LocalTime.of(6, 15)
    val FALLBACK_MORNING: LocalTime = LocalTime.of(7, 0)
    val FALLBACK_AFTER_ASR: LocalTime = LocalTime.of(17, 0)
    val FALLBACK_AFTER_MAGHRIB: LocalTime = LocalTime.of(19, 15)

    fun resolve(
        preset: OnboardingReminderPreset,
        fajr: LocalTime?,
        asr: LocalTime?,
        maghrib: LocalTime?,
    ): LocalTime = when (preset) {
        OnboardingReminderPreset.AFTER_FAJR ->
            fajr?.plusMinutes(PRAYER_OFFSET_MINUTES) ?: FALLBACK_AFTER_FAJR
        OnboardingReminderPreset.MORNING -> FALLBACK_MORNING
        OnboardingReminderPreset.AFTER_ASR ->
            asr?.plusMinutes(PRAYER_OFFSET_MINUTES) ?: FALLBACK_AFTER_ASR
        OnboardingReminderPreset.AFTER_MAGHRIB ->
            maghrib?.plusMinutes(MAGHRIB_OFFSET_MINUTES) ?: FALLBACK_AFTER_MAGHRIB
    }
}
