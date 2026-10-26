package app.awrad.feature.account.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.core.domain.account.AccountError
import app.awrad.core.domain.account.AccountResult
import app.awrad.core.domain.account.AccountSettingsRepository
import app.awrad.core.domain.account.EmailAddress
import app.awrad.core.domain.account.EmailCode
import app.awrad.core.domain.account.InputProblem
import app.awrad.feature.account.EmailProblems
import app.awrad.feature.account.ResendCooldown
import app.awrad.feature.account.firstOf
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/** The steps of changing the email: the form, the code sent to the new address, and the result. */
internal enum class ChangeEmailStep { FORM, CODE, DONE }

/**
 * The change-email flow. [currentPassword] stays in memory until the flow ends, so "send a new code" can
 * repeat the request. [changedTo] is the account's email once it changed.
 */
internal data class ChangeEmailUiState(
    val step: ChangeEmailStep = ChangeEmailStep.FORM,
    val currentPassword: String = "",
    val newEmail: String = "",
    val code: String = "",
    val fieldProblems: Set<InputProblem> = emptySet(),
    val error: AccountError? = null,
    val isCodeSent: Boolean = false,
    val isBusy: Boolean = false,
    val resendCooldownSeconds: Int = 0,
    val changedTo: String? = null,
) {
    val currentPasswordProblem: InputProblem?
        get() = fieldProblems.firstOf(setOf(InputProblem.CURRENT_PASSWORD_INCORRECT))

    val newEmailProblem: InputProblem? get() = fieldProblems.firstOf(EmailProblems)

    val codeProblem: InputProblem? get() = fieldProblems.firstOf(setOf(InputProblem.CODE_INVALID))

    val canSubmit: Boolean
        get() = !isBusy && when (step) {
            ChangeEmailStep.FORM -> currentPassword.isNotEmpty() && newEmail.isNotBlank()
            ChangeEmailStep.CODE -> code.isNotBlank()
            ChangeEmailStep.DONE -> false
        }

    val canResend: Boolean get() = !isBusy && resendCooldownSeconds == 0
}

internal sealed interface ChangeEmailAction {
    data class CurrentPasswordChanged(val value: String) : ChangeEmailAction

    data class NewEmailChanged(val value: String) : ChangeEmailAction

    data class CodeChanged(val value: String) : ChangeEmailAction

    /** Sends the code (form) or confirms it (code). */
    data object Submit : ChangeEmailAction

    data object ResendCode : ChangeEmailAction

    /** From the code back to the form, to use a different address. */
    data object EditEmail : ChangeEmailAction
}

/**
 * Changes the account's email: the current password and the new address send a code to the new address,
 * and the email changes only when that code is confirmed. Sessions stay signed in.
 */
@HiltViewModel
internal class ChangeEmailViewModel @Inject constructor(
    private val settings: AccountSettingsRepository,
) : ViewModel() {

    private val mutableState = MutableStateFlow(ChangeEmailUiState())
    val state: StateFlow<ChangeEmailUiState> = mutableState.asStateFlow()

    private val cooldown = ResendCooldown(viewModelScope) { left ->
        mutableState.update { it.copy(resendCooldownSeconds = left) }
    }

    fun onAction(action: ChangeEmailAction) {
        when (action) {
            is ChangeEmailAction.CurrentPasswordChanged -> edit { copy(currentPassword = action.value) }
            is ChangeEmailAction.NewEmailChanged -> edit { copy(newEmail = action.value) }
            is ChangeEmailAction.CodeChanged -> edit { copy(code = action.value) }
            ChangeEmailAction.Submit -> submit()
            ChangeEmailAction.ResendCode -> if (mutableState.value.canResend) requestCode()
            ChangeEmailAction.EditEmail -> edit { copy(step = ChangeEmailStep.FORM, code = "", isCodeSent = false) }
        }
    }

    private fun submit() {
        val current = mutableState.value
        if (!current.canSubmit) return
        when (current.step) {
            ChangeEmailStep.FORM -> requestCode()
            ChangeEmailStep.CODE -> confirm()
            ChangeEmailStep.DONE -> Unit
        }
    }

    private fun requestCode() {
        val current = mutableState.value
        val email = EmailAddress.parse(current.newEmail)
        if (email == null) {
            reject(setOf(InputProblem.EMAIL_INVALID))
            return
        }
        busy {
            when (val result = settings.requestEmailChange(current.currentPassword, email)) {
                is AccountResult.Success -> {
                    mutableState.update {
                        it.copy(step = ChangeEmailStep.CODE, code = "", isCodeSent = true, newEmail = email.value)
                    }
                    cooldown.start()
                }
                is AccountResult.Failure -> fail(result.error)
            }
        }
    }

    private fun confirm() {
        val code = EmailCode.parse(mutableState.value.code)
        if (code == null) {
            reject(setOf(InputProblem.CODE_INVALID))
            return
        }
        busy {
            when (val result = settings.confirmEmailChange(code)) {
                is AccountResult.Success -> mutableState.value = ChangeEmailUiState(
                    step = ChangeEmailStep.DONE,
                    changedTo = result.value.email,
                )
                is AccountResult.Failure -> fail(result.error)
            }
        }
    }

    /**
     * Field problems go under their fields; a problem with the password or address (when resending) goes
     * back to the form, where those fields are.
     */
    private fun fail(error: AccountError) {
        if (error is AccountError.RateLimited) cooldown.start(error.retryAfterSeconds)
        mutableState.update {
            val problems = (error as? AccountError.InvalidInput)?.problems.orEmpty()
            when {
                problems.isEmpty() -> it.copy(error = error, isCodeSent = false)
                problems.any { problem -> problem != InputProblem.CODE_INVALID } ->
                    it.copy(step = ChangeEmailStep.FORM, fieldProblems = problems, isCodeSent = false)
                else -> it.copy(fieldProblems = problems, isCodeSent = false)
            }
        }
    }

    private fun reject(problems: Set<InputProblem>) {
        mutableState.update { it.copy(fieldProblems = problems, error = null) }
    }

    private fun busy(block: suspend () -> Unit) {
        mutableState.update { it.copy(isBusy = true, error = null, fieldProblems = emptySet()) }
        viewModelScope.launch {
            try {
                block()
            } finally {
                mutableState.update { it.copy(isBusy = false) }
            }
        }
    }

    private fun edit(change: ChangeEmailUiState.() -> ChangeEmailUiState) {
        mutableState.update { it.change().copy(fieldProblems = emptySet(), error = null) }
    }
}
