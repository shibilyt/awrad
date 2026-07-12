package app.awrad.awrad_dhikrgoalstracker.ui.screens.onboarding

import java.time.LocalTime
import org.junit.Assert.assertEquals
import org.junit.Test

class OnboardingReminderPresetsTest {

    private val fajr = LocalTime.of(4, 42)
    private val asr = LocalTime.of(15, 21)
    private val maghrib = LocalTime.of(18, 49)

    @Test
    fun `prayer-anchored presets offset from the actual prayer times`() {
        assertEquals(
            LocalTime.of(5, 12),
            OnboardingReminderTimes.resolve(OnboardingReminderPreset.AFTER_FAJR, fajr, asr, maghrib),
        )
        assertEquals(
            LocalTime.of(15, 51),
            OnboardingReminderTimes.resolve(OnboardingReminderPreset.AFTER_ASR, fajr, asr, maghrib),
        )
        assertEquals(
            LocalTime.of(19, 4),
            OnboardingReminderTimes.resolve(OnboardingReminderPreset.AFTER_MAGHRIB, fajr, asr, maghrib),
        )
    }

    @Test
    fun `morning preset is a fixed seven o'clock regardless of prayer times`() {
        assertEquals(
            LocalTime.of(7, 0),
            OnboardingReminderTimes.resolve(OnboardingReminderPreset.MORNING, fajr, asr, maghrib),
        )
        assertEquals(
            LocalTime.of(7, 0),
            OnboardingReminderTimes.resolve(OnboardingReminderPreset.MORNING, null, null, null),
        )
    }

    @Test
    fun `presets fall back to sensible defaults without a location`() {
        assertEquals(
            OnboardingReminderTimes.FALLBACK_AFTER_FAJR,
            OnboardingReminderTimes.resolve(OnboardingReminderPreset.AFTER_FAJR, null, null, null),
        )
        assertEquals(
            OnboardingReminderTimes.FALLBACK_AFTER_ASR,
            OnboardingReminderTimes.resolve(OnboardingReminderPreset.AFTER_ASR, null, null, null),
        )
        assertEquals(
            OnboardingReminderTimes.FALLBACK_AFTER_MAGHRIB,
            OnboardingReminderTimes.resolve(OnboardingReminderPreset.AFTER_MAGHRIB, null, null, null),
        )
    }

    @Test
    fun `offsets roll cleanly across midnight-safe boundaries`() {
        // A late maghrib (e.g. northern summer) still lands on a valid time.
        val lateMaghrib = LocalTime.of(23, 55)
        assertEquals(
            LocalTime.of(0, 10),
            OnboardingReminderTimes.resolve(OnboardingReminderPreset.AFTER_MAGHRIB, fajr, asr, lateMaghrib),
        )
    }
}
