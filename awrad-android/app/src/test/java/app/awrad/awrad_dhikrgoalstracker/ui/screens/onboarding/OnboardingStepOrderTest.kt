package app.awrad.awrad_dhikrgoalstracker.ui.screens.onboarding

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class OnboardingStepOrderTest {

    @Test
    fun `flow opens cinematically, then language, then account`() {
        assertEquals(0, OnboardingViewModel.OPENING_STEP_INDEX)
        assertEquals(OnboardingViewModel.OPENING_STEP_INDEX + 1, OnboardingViewModel.LANGUAGE_STEP_INDEX)
        assertEquals(OnboardingViewModel.LANGUAGE_STEP_INDEX + 1, OnboardingViewModel.ACCOUNT_STEP_INDEX)
        assertEquals(OnboardingViewModel.ACCOUNT_STEP_INDEX + 1, OnboardingViewModel.NAME_STEP_INDEX)
    }

    @Test
    fun `prayer setup precedes notifications and reminder presets`() {
        assertEquals(OnboardingViewModel.NAME_STEP_INDEX + 1, OnboardingViewModel.LOCATION_STEP_INDEX)
        assertEquals(OnboardingViewModel.LOCATION_STEP_INDEX + 1, OnboardingViewModel.NOTIFICATIONS_STEP_INDEX)
        assertEquals(OnboardingViewModel.NOTIFICATIONS_STEP_INDEX + 1, OnboardingViewModel.REMINDERS_STEP_INDEX)
    }

    @Test
    fun `audio comes after reminders, before the goal finale`() {
        assertEquals(OnboardingViewModel.REMINDERS_STEP_INDEX + 1, OnboardingViewModel.AUDIO_STEP_INDEX)
        assertEquals(OnboardingViewModel.AUDIO_STEP_INDEX + 1, OnboardingViewModel.GOAL_INTRO_STEP_INDEX)
    }

    @Test
    fun `first goal is the final step, right after its cinematic intro`() {
        assertEquals(OnboardingViewModel.GOAL_INTRO_STEP_INDEX + 1, OnboardingViewModel.FIRST_GOAL_STEP_INDEX)
        assertEquals(OnboardingViewModel.TOTAL_STEPS - 1, OnboardingViewModel.FIRST_GOAL_STEP_INDEX)
    }

    @Test
    fun `onboarding has ten scenes`() {
        assertEquals(10, OnboardingViewModel.TOTAL_STEPS)
    }

    @Test
    fun `returning user goes from account through device setup and then completes`() {
        assertEquals(
            listOf(
                OnboardingViewModel.OPENING_STEP_INDEX,
                OnboardingViewModel.LANGUAGE_STEP_INDEX,
                OnboardingViewModel.ACCOUNT_STEP_INDEX,
                OnboardingViewModel.LOCATION_STEP_INDEX,
                OnboardingViewModel.NOTIFICATIONS_STEP_INDEX,
                OnboardingViewModel.AUDIO_STEP_INDEX,
            ),
            OnboardingViewModel.visibleSteps(returningUser = true),
        )
        assertEquals(
            OnboardingViewModel.LOCATION_STEP_INDEX,
            OnboardingViewModel.nextStepIndex(OnboardingViewModel.ACCOUNT_STEP_INDEX, returningUser = true),
        )
        assertEquals(
            OnboardingViewModel.NOTIFICATIONS_STEP_INDEX,
            OnboardingViewModel.nextStepIndex(OnboardingViewModel.LOCATION_STEP_INDEX, returningUser = true),
        )
        assertEquals(
            OnboardingViewModel.AUDIO_STEP_INDEX,
            OnboardingViewModel.nextStepIndex(OnboardingViewModel.NOTIFICATIONS_STEP_INDEX, returningUser = true),
        )
        assertNull(OnboardingViewModel.nextStepIndex(OnboardingViewModel.AUDIO_STEP_INDEX, returningUser = true))
        assertEquals(
            OnboardingViewModel.NOTIFICATIONS_STEP_INDEX,
            OnboardingViewModel.previousStepIndex(OnboardingViewModel.AUDIO_STEP_INDEX, returningUser = true),
        )
    }
}
