package app.awrad.feature.account.settings

import androidx.compose.runtime.State
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.core.domain.account.AccountError
import app.awrad.core.domain.account.AccountResult
import app.awrad.core.domain.account.AccountSettingsRepository
import app.awrad.core.domain.account.InputProblem
import app.awrad.feature.account.NewPasswordProblems
import app.awrad.feature.account.firstOf
import app.awrad.feature.account.newPasswordProblems
import app.awrad.feature.account.update
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject

/** The change-password form. [isDone] after the server took the new password. */
internal data class ChangePasswordUiState(
    val currentPassword: String = "",
    val newPassword: String = "",
    val fieldProblems: Set<InputProblem> = emptySet(),
    val error: AccountError? = null,
    val isBusy: Boolean = false,
    val isDone: Boolean = false,
) {
    val currentPasswordProblem: InputProblem?
        get() = fieldProblems.firstOf(setOf(InputProblem.CURRENT_PASSWORD_INCORRECT))

    val newPasswordProblem: InputProblem? get() = fieldProblems.firstOf(NewPasswordProblems)

    val canSubmit: Boolean get() = !isBusy && currentPassword.isNotEmpty() && newPassword.isNotEmpty()
}

internal sealed interface ChangePasswordAction {
    data class CurrentPasswordChanged(val value: String) : ChangePasswordAction

    data class NewPasswordChanged(val value: String) : ChangePasswordAction

    data object Submit : ChangePasswordAction
}

/**
 * Changes the password with the current one. The server signs out every other device and browser and
 * keeps this one. The new password is checked against the shared policy before it's sent.
 */
@HiltViewModel
internal class ChangePasswordViewModel @Inject constructor(
    private val settings: AccountSettingsRepository,
) : ViewModel() {

    private val mutableState = mutableStateOf(ChangePasswordUiState())
    val state: State<ChangePasswordUiState> = mutableState

    fun onAction(action: ChangePasswordAction) {
        when (action) {
            is ChangePasswordAction.CurrentPasswordChanged -> edit { copy(currentPassword = action.value) }
            is ChangePasswordAction.NewPasswordChanged -> edit { copy(newPassword = action.value) }
            ChangePasswordAction.Submit -> submit()
        }
    }

    private fun submit() {
        val current = mutableState.value
        if (!current.canSubmit) return
        val problems = newPasswordProblems(current.newPassword)
        if (problems.isNotEmpty()) {
            mutableState.update { it.copy(fieldProblems = problems, error = null) }
            return
        }
        mutableState.update { it.copy(isBusy = true, error = null, fieldProblems = emptySet()) }
        viewModelScope.launch {
            val result = settings.changePassword(current.currentPassword, current.newPassword)
            mutableState.update {
                when (result) {
                    is AccountResult.Success -> ChangePasswordUiState(isDone = true)
                    is AccountResult.Failure -> it.failedWith(result.error)
                }
            }
        }
    }

    private fun edit(change: ChangePasswordUiState.() -> ChangePasswordUiState) {
        mutableState.update { it.change().copy(fieldProblems = emptySet(), error = null, isDone = false) }
    }
}

/** Field problems go under their fields; anything else is the page's error. */
private fun ChangePasswordUiState.failedWith(error: AccountError): ChangePasswordUiState =
    if (error is AccountError.InvalidInput && error.problems.isNotEmpty()) {
        copy(isBusy = false, fieldProblems = error.problems)
    } else {
        copy(isBusy = false, error = error)
    }
