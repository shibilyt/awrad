package app.awrad.feature.onboarding

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.core.domain.onboarding.OnboardingStatusStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/** Placeholder: proves the feature → port → adapter wiring. Real onboarding replaces it. */
@HiltViewModel
internal class OnboardingViewModel @Inject constructor(
    private val status: OnboardingStatusStore,
) : ViewModel() {

    private val mutableState = MutableStateFlow(OnboardingUiState())
    val state: StateFlow<OnboardingUiState> = mutableState.asStateFlow()

    fun onAction(action: OnboardingAction) {
        when (action) {
            OnboardingAction.GetStarted -> finish()
        }
    }

    private fun finish() {
        if (mutableState.value.isFinishing) return
        mutableState.update { it.copy(isFinishing = true) }
        viewModelScope.launch {
            status.markOnboarded()
            mutableState.update { it.copy(isFinishing = false, isFinished = true) }
        }
    }
}

internal data class OnboardingUiState(
    val isFinishing: Boolean = false,
    val isFinished: Boolean = false,
)

internal sealed interface OnboardingAction {
    data object GetStarted : OnboardingAction
}
