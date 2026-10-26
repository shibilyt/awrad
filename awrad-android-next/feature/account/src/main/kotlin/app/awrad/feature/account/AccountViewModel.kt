package app.awrad.feature.account

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.core.domain.account.AccountError
import app.awrad.core.domain.account.AccountRepository
import app.awrad.core.domain.account.AccountResult
import app.awrad.core.domain.account.AccountSession
import app.awrad.core.domain.account.EmailAddress
import app.awrad.core.domain.account.EmailCode
import app.awrad.core.domain.account.InputProblem
import app.awrad.core.domain.account.PasswordError
import app.awrad.core.domain.account.PasswordPolicy
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * The account flow: sign in, register, verify the email, reset the password, and the signed-in account.
 * Inputs are checked with the shared account-model rules before anything is sent.
 */
@HiltViewModel
internal class AccountViewModel @Inject constructor(
    private val accounts: AccountRepository,
) : ViewModel() {

    private val mutableState = MutableStateFlow(AccountUiState())
    val state: StateFlow<AccountUiState> = mutableState.asStateFlow()

    private var cooldown: Job? = null

    init {
        viewModelScope.launch { accounts.session.collect(::onSession) }
    }

    fun onAction(action: AccountAction) {
        when (action) {
            is AccountAction.EmailChanged -> edit { copy(email = action.value) }
            is AccountAction.PasswordChanged -> edit { copy(password = action.value) }
            is AccountAction.CodeChanged -> edit { copy(code = action.value) }
            AccountAction.Submit -> submit()
            AccountAction.ResendCode -> resendCode()
            AccountAction.GoToRegister -> goTo(AccountStep.REGISTER)
            AccountAction.GoToSignIn -> goTo(AccountStep.SIGN_IN)
            AccountAction.GoToForgotPassword -> goTo(AccountStep.FORGOT_PASSWORD)
            AccountAction.Back -> mutableState.value.step?.previous?.let(::goTo)
            AccountAction.SignOut -> viewModelScope.launch { accounts.signOut() }
        }
    }

    private fun onSession(session: AccountSession) {
        when (session) {
            is AccountSession.SignedIn -> {
                val wasSignedIn = mutableState.value.step == AccountStep.SIGNED_IN
                mutableState.value = AccountUiState(step = AccountStep.SIGNED_IN, account = session.account)
                if (!wasSignedIn) viewModelScope.launch { accounts.refreshAccount() }
            }
            AccountSession.SignedOut -> mutableState.update { current ->
                when (current.step) {
                    null -> AccountUiState(step = AccountStep.SIGN_IN)
                    AccountStep.SIGNED_IN -> AccountUiState(
                        step = AccountStep.SIGN_IN,
                        notice = AccountNotice.SIGNED_OUT,
                    )
                    else -> current
                }
            }
        }
    }

    private fun submit() {
        val current = mutableState.value
        if (!current.canSubmit) return
        when (current.step) {
            AccountStep.SIGN_IN -> withEmail { email -> signIn(email, current.password) }
            AccountStep.REGISTER -> withEmail { email -> withPassword { register(email, current.password) } }
            AccountStep.VERIFY_EMAIL -> withEmail { email -> withCode { code -> verify(email, code) } }
            AccountStep.FORGOT_PASSWORD -> withEmail { email -> requestReset(email) }
            AccountStep.RESET_PASSWORD -> withEmail { email ->
                withCode { code -> withPassword { resetPassword(email, code, current.password) } }
            }
            AccountStep.SIGNED_IN, null -> Unit
        }
    }

    private suspend fun signIn(email: EmailAddress, password: String) {
        when (val result = accounts.signIn(email, password)) {
            is AccountResult.Success -> Unit // The session flow moves to the account screen.
            is AccountResult.Failure -> if (result.error == AccountError.EmailVerificationRequired) {
                // The server has emailed a fresh code.
                moveTo(AccountStep.VERIFY_EMAIL, AccountNotice.VERIFICATION_REQUIRED)
                startCooldown()
            } else {
                fail(result.error)
            }
        }
    }

    private suspend fun register(email: EmailAddress, password: String) {
        codeSent(accounts.register(email, password), AccountStep.VERIFY_EMAIL)
    }

    private suspend fun verify(email: EmailAddress, code: EmailCode) {
        when (val result = accounts.verifyEmail(email, code)) {
            is AccountResult.Success -> signInAfter(email, AccountNotice.EMAIL_VERIFIED)
            is AccountResult.Failure -> fail(result.error)
        }
    }

    private suspend fun requestReset(email: EmailAddress) {
        mutableState.update { it.copy(password = "", code = "") }
        codeSent(accounts.requestPasswordReset(email), AccountStep.RESET_PASSWORD)
    }

    private suspend fun resetPassword(email: EmailAddress, code: EmailCode, newPassword: String) {
        when (val result = accounts.resetPassword(email, code, newPassword)) {
            is AccountResult.Success -> signInAfter(email, AccountNotice.PASSWORD_CHANGED)
            is AccountResult.Failure -> fail(result.error)
        }
    }

    /**
     * Verifying and resetting don't sign in (ADR-2026-10-26): sign in with the password typed earlier. If
     * it's gone (the process was recreated) or doesn't work, the sign-in form says what happened.
     */
    private suspend fun signInAfter(email: EmailAddress, notice: AccountNotice) {
        val password = mutableState.value.password
        if (password.isEmpty()) {
            moveTo(AccountStep.SIGN_IN, notice)
            return
        }
        val result = accounts.signIn(email, password)
        if (result is AccountResult.Failure) {
            moveTo(AccountStep.SIGN_IN, notice)
            fail(result.error)
        }
    }

    private suspend fun codeSent(result: AccountResult<Unit>, next: AccountStep) {
        when (result) {
            is AccountResult.Success -> {
                moveTo(next, AccountNotice.CODE_SENT)
                startCooldown()
            }
            is AccountResult.Failure -> fail(result.error)
        }
    }

    private fun resendCode() {
        val current = mutableState.value
        if (!current.canResend) return
        val email = EmailAddress.parse(current.email) ?: return
        busy {
            val result = when (current.step) {
                AccountStep.VERIFY_EMAIL -> accounts.resendVerificationCode(email)
                AccountStep.RESET_PASSWORD -> accounts.requestPasswordReset(email)
                else -> return@busy
            }
            when (result) {
                is AccountResult.Success -> {
                    mutableState.update { it.copy(notice = AccountNotice.CODE_SENT, error = null, code = "") }
                    startCooldown()
                }
                is AccountResult.Failure -> fail(result.error)
            }
        }
    }

    private fun withEmail(then: suspend (EmailAddress) -> Unit) {
        val email = EmailAddress.parse(mutableState.value.email)
        if (email == null) {
            reject(setOf(InputProblem.EMAIL_INVALID))
        } else {
            busy { then(email) }
        }
    }

    private suspend fun withPassword(then: suspend () -> Unit) {
        val problems = PasswordPolicy.errors(mutableState.value.password).mapTo(mutableSetOf()) { error ->
            when (error) {
                PasswordError.PASSWORD_TOO_SHORT -> InputProblem.PASSWORD_TOO_SHORT
                PasswordError.PASSWORD_TOO_LONG -> InputProblem.PASSWORD_TOO_LONG
            }
        }
        if (problems.isEmpty()) then() else reject(problems)
    }

    private suspend fun withCode(then: suspend (EmailCode) -> Unit) {
        val code = EmailCode.parse(mutableState.value.code)
        if (code == null) reject(setOf(InputProblem.CODE_INVALID)) else then(code)
    }

    /** Runs [block] with the form busy; a second submit while busy is ignored. */
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

    private fun reject(problems: Set<InputProblem>) {
        mutableState.update { it.copy(fieldProblems = problems, error = null) }
    }

    private fun fail(error: AccountError) {
        if (error is AccountError.RateLimited) startCooldown(error.retryAfterSeconds)
        mutableState.update {
            if (error is AccountError.InvalidInput && error.problems.isNotEmpty()) {
                it.copy(fieldProblems = error.problems, error = null, notice = null)
            } else {
                it.copy(error = error, notice = null)
            }
        }
    }

    private fun edit(change: AccountUiState.() -> AccountUiState) {
        mutableState.update { it.change().copy(fieldProblems = emptySet(), error = null) }
    }

    private fun goTo(step: AccountStep) = moveTo(step, notice = null)

    private fun moveTo(step: AccountStep, notice: AccountNotice?) {
        mutableState.update {
            it.copy(step = step, notice = notice, code = "", error = null, fieldProblems = emptySet())
        }
    }

    /** The server's 202 says nothing about when to resend, so wait [seconds] (or `Retry-After`). */
    private fun startCooldown(seconds: Long? = null) {
        cooldown?.cancel()
        val total = (seconds ?: RESEND_COOLDOWN_SECONDS).coerceIn(1, MAX_COOLDOWN_SECONDS).toInt()
        mutableState.update { it.copy(resendCooldownSeconds = total) }
        cooldown = viewModelScope.launch {
            for (left in total - 1 downTo 0) {
                delay(ONE_SECOND_MS)
                mutableState.update { it.copy(resendCooldownSeconds = left) }
            }
        }
    }

    internal companion object {
        const val RESEND_COOLDOWN_SECONDS = 60L
        private const val MAX_COOLDOWN_SECONDS = 3_600L
        private const val ONE_SECOND_MS = 1_000L
    }
}
