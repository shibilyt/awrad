package app.awrad.next.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.core.domain.onboarding.OnboardingStatusStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject

/** Home's stand-in actions until the real home feature exists. */
@HiltViewModel
class HomePlaceholderViewModel @Inject constructor(
    private val status: OnboardingStatusStore,
) : ViewModel() {
    fun restartOnboarding(then: () -> Unit) {
        viewModelScope.launch {
            status.reset()
            then()
        }
    }
}
