package app.awrad.feature.account.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.core.domain.account.AccountError
import app.awrad.core.domain.account.AccountResult
import app.awrad.core.domain.account.AccountSettingsRepository
import app.awrad.core.domain.account.InputProblem
import app.awrad.feature.account.firstOf
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/** The delete-account page: the password, then a last confirmation. */
internal data class DeleteAccountUiState(
    val password: String = "",
    val fieldProblems: Set<InputProblem> = emptySet(),
    val error: AccountError? = null,
    val isBusy: Boolean = false,
    val isConfirming: Boolean = false,
) {
    val passwordProblem: InputProblem? get() = fieldProblems.firstOf(setOf(InputProblem.CURRENT_PASSWORD_INCORRECT))

    val canSubmit: Boolean get() = !isBusy && password.isNotEmpty()
}

internal sealed interface DeleteAccountAction {
    data class PasswordChanged(val value: String) : DeleteAccountAction

    /** The page's delete button: asks to confirm. */
    data object Submit : DeleteAccountAction

    /** The confirmation's delete button: deletes. */
    data object Confirm : DeleteAccountAction

    data object Dismiss : DeleteAccountAction
}

/**
 * Deletes the account, after the password and a confirmation. On success the device is signed out
 * ([app.awrad.core.domain.account.SignOutReason.ACCOUNT_DELETED]) and the account flow says so; practice
 * data on the device stays.
 */
@HiltViewModel
internal class DeleteAccountViewModel @Inject constructor(
    private val settings: AccountSettingsRepository,
) : ViewModel() {

    private val mutableState = MutableStateFlow(DeleteAccountUiState())
    val state: StateFlow<DeleteAccountUiState> = mutableState.asStateFlow()

    fun onAction(action: DeleteAccountAction) {
        when (action) {
            is DeleteAccountAction.PasswordChanged -> mutableState.update {
                it.copy(password = action.value, fieldProblems = emptySet(), error = null)
            }
            DeleteAccountAction.Submit -> if (mutableState.value.canSubmit) {
                mutableState.update { it.copy(isConfirming = true, error = null, fieldProblems = emptySet()) }
            }
            DeleteAccountAction.Confirm -> delete()
            DeleteAccountAction.Dismiss -> mutableState.update { it.copy(isConfirming = false) }
        }
    }

    private fun delete() {
        val current = mutableState.value
        if (!current.isConfirming || !current.canSubmit) return
        mutableState.update { it.copy(isConfirming = false, isBusy = true) }
        viewModelScope.launch {
            val result = settings.deleteAccount(current.password)
            mutableState.update {
                when (result) {
                    // The session flow takes the person to the signed-out account screen.
                    is AccountResult.Success -> DeleteAccountUiState()
                    is AccountResult.Failure -> {
                        val problems = (result.error as? AccountError.InvalidInput)?.problems.orEmpty()
                        if (problems.isEmpty()) {
                            it.copy(isBusy = false, error = result.error)
                        } else {
                            it.copy(isBusy = false, fieldProblems = problems)
                        }
                    }
                }
            }
        }
    }
}
