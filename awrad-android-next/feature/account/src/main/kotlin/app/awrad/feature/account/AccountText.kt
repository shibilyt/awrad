package app.awrad.feature.account

import androidx.annotation.StringRes
import androidx.compose.runtime.Composable
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import app.awrad.core.domain.account.AccountError
import app.awrad.core.domain.account.InputProblem
import app.awrad.core.domain.account.PasswordPolicy

/*
 * Typed errors and notices to string resources. Server English (`title`, `detail`) is never shown.
 */

@StringRes
internal fun AccountError.message(): Int = when (this) {
    is AccountError.InvalidInput -> R.string.account_error_invalid_input
    AccountError.VerificationCodeInvalid -> R.string.account_error_verification_code_invalid
    AccountError.ResetCodeInvalid -> R.string.account_error_reset_code_invalid
    AccountError.EmailChangeCodeInvalid -> R.string.account_error_email_change_code_invalid
    AccountError.EmailTaken -> R.string.account_error_email_taken
    AccountError.NotFound -> R.string.account_error_not_found
    AccountError.InvalidCredentials -> R.string.account_error_invalid_credentials
    AccountError.EmailVerificationRequired -> R.string.account_notice_verification_required
    AccountError.SessionEnded -> R.string.account_error_session_ended
    is AccountError.RateLimited -> R.string.account_error_rate_limited
    AccountError.RequestRejected -> R.string.account_error_request_rejected
    AccountError.NoConnection -> R.string.account_error_no_connection
    AccountError.Unexpected -> R.string.account_error_unexpected
}

/** The text under a field. Length problems state the shared password policy's numbers. */
@Composable
internal fun InputProblem.text(): String = when (this) {
    InputProblem.EMAIL_INVALID -> stringResource(R.string.account_error_email_invalid)
    InputProblem.PASSWORD_TOO_SHORT -> PasswordPolicy.MIN_LENGTH.let {
        pluralStringResource(R.plurals.account_error_password_too_short, it, it)
    }
    InputProblem.PASSWORD_TOO_LONG -> PasswordPolicy.MAX_LENGTH.let {
        pluralStringResource(R.plurals.account_error_password_too_long, it, it)
    }
    InputProblem.PASSWORD_TOO_COMMON -> stringResource(R.string.account_error_password_too_common)
    InputProblem.CODE_INVALID -> stringResource(R.string.account_error_code_format)
    InputProblem.CURRENT_PASSWORD_INCORRECT -> stringResource(R.string.account_error_current_password_incorrect)
    InputProblem.EMAIL_UNCHANGED -> stringResource(R.string.account_error_email_unchanged)
}

/** The password hint: the 12-character rule. */
@Composable
internal fun passwordRuleText(): String =
    PasswordPolicy.MIN_LENGTH.let { pluralStringResource(R.plurals.account_hint_password, it, it) }

@StringRes
internal fun AccountNotice.message(): Int = when (this) {
    AccountNotice.CODE_SENT -> R.string.account_notice_code_sent
    AccountNotice.VERIFICATION_REQUIRED -> R.string.account_notice_verification_required
    AccountNotice.EMAIL_VERIFIED -> R.string.account_notice_email_verified
    AccountNotice.PASSWORD_CHANGED -> R.string.account_notice_password_changed
    AccountNotice.SIGNED_OUT -> R.string.account_notice_signed_out
    AccountNotice.SESSION_ENDED -> R.string.account_notice_session_ended
    AccountNotice.ACCOUNT_DELETED -> R.string.account_notice_account_deleted
}

@StringRes
internal fun AccountStep.title(): Int = when (this) {
    AccountStep.SIGN_IN -> R.string.account_title_sign_in
    AccountStep.REGISTER -> R.string.account_title_register
    AccountStep.VERIFY_EMAIL -> R.string.account_title_verify
    AccountStep.FORGOT_PASSWORD -> R.string.account_title_forgot
    AccountStep.RESET_PASSWORD -> R.string.account_title_reset
    AccountStep.SIGNED_IN -> R.string.account_title_signed_in
}
