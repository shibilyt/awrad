package app.awrad.feature.onboarding

import app.awrad.core.testing.FakeOnboardingStatusStore
import app.awrad.core.testing.MainDispatcherRule
import org.junit.Rule
import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class OnboardingViewModelTest {

    @get:Rule
    val mainDispatcher = MainDispatcherRule()

    private val status = FakeOnboardingStatusStore()
    private val viewModel = OnboardingViewModel(status)

    @Test
    fun `getting started marks the installation onboarded and finishes`() {
        viewModel.onAction(OnboardingAction.GetStarted)

        assertTrue(status.value)
        assertTrue(viewModel.state.value.isFinished)
        assertFalse(viewModel.state.value.isFinishing)
    }
}
