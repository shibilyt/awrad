package app.awrad.feature.account

import app.awrad.core.domain.account.Account
import app.awrad.core.domain.account.AccountError
import app.awrad.core.domain.account.InputProblem

/** The screens of the account flow. */
internal enum class AccountStep {
    SIGN_IN,
    REGISTER,
    VERIFY_EMAIL,
    FORGOT_PASSWORD,
    RESET_PASSWORD,
    SIGNED_IN,
    ;

    /** Where Back goes inside the flow; null leaves the flow. */
    val previous: AccountStep?
        get() = when (this) {
            REGISTER, VERIFY_EMAIL, FORGOT_PASSWORD -> SIGN_IN
            RESET_PASSWORD -> FORGOT_PASSWORD
            SIGN_IN, SIGNED_IN -> null
        }
}

/** A short confirmation shown above the form. */
internal enum class AccountNotice {
    CODE_SENT,
    VERIFICATION_REQUIRED,
    EMAIL_VERIFIED,
    PASSWORD_CHANGED,
    SIGNED_OUT,
}

/**
 * Everything the account screens show. [password] is the password on sign-in and register, and the new
 * password on reset; it's kept in memory only, so verifying can sign in with it.
 */
internal data class AccountUiState(
    /** Null until the stored session has loaded. */
    val step: AccountStep? = null,
    val email: String = "",
    val password: String = "",
    val code: String = "",
    val account: Account? = null,
    val fieldProblems: Set<InputProblem> = emptySet(),
    val error: AccountError? = null,
    val notice: AccountNotice? = null,
    val isBusy: Boolean = false,
    val resendCooldownSeconds: Int = 0,
) {
    val emailProblem: InputProblem? get() = fieldProblems.firstOrNull { it == InputProblem.EMAIL_INVALID }

    val passwordProblem: InputProblem? get() = fieldProblems.firstOrNull { it in PASSWORD_PROBLEMS }

    val codeProblem: InputProblem? get() = fieldProblems.firstOrNull { it == InputProblem.CODE_INVALID }

    val canGoBack: Boolean get() = step?.previous != null

    val canResend: Boolean get() = !isBusy && resendCooldownSeconds == 0

    /** The primary button needs something in every field of the step. */
    val canSubmit: Boolean
        get() = !isBusy && when (step) {
            AccountStep.SIGN_IN, AccountStep.REGISTER -> email.isNotBlank() && password.isNotEmpty()
            AccountStep.FORGOT_PASSWORD -> email.isNotBlank()
            AccountStep.VERIFY_EMAIL -> code.isNotBlank()
            AccountStep.RESET_PASSWORD -> code.isNotBlank() && password.isNotEmpty()
            AccountStep.SIGNED_IN, null -> false
        }

    private companion object {
        val PASSWORD_PROBLEMS = setOf(
            InputProblem.PASSWORD_TOO_SHORT,
            InputProblem.PASSWORD_TOO_LONG,
            InputProblem.PASSWORD_TOO_COMMON,
        )
    }
}

/** Everything the account screens can ask for. */
internal sealed interface AccountAction {
    data class EmailChanged(val value: String) : AccountAction

    data class PasswordChanged(val value: String) : AccountAction

    data class CodeChanged(val value: String) : AccountAction

    /** The step's primary button: sign in, register, verify, send the reset code, or set the new password. */
    data object Submit : AccountAction

    data object ResendCode : AccountAction

    data object GoToRegister : AccountAction

    data object GoToSignIn : AccountAction

    data object GoToForgotPassword : AccountAction

    data object Back : AccountAction

    data object SignOut : AccountAction
}
