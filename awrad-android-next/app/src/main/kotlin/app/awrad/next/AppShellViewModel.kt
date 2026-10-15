package app.awrad.next

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.core.domain.onboarding.OnboardingStatusStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

/** Decides where the app starts. */
@HiltViewModel
class AppShellViewModel @Inject constructor(
    status: OnboardingStatusStore,
) : ViewModel() {

    val startDestination: StateFlow<StartDestination?> = status.isOnboarded
        .map { onboarded -> if (onboarded) StartDestination.Home else StartDestination.Onboarding }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(STOP_TIMEOUT_MS), initialValue = null)

    private companion object {
        const val STOP_TIMEOUT_MS = 5_000L
    }
}

enum class StartDestination { Onboarding, Home }
