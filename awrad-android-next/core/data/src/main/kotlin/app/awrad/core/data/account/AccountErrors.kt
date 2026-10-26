package app.awrad.core.data.account

import app.awrad.core.domain.account.AccountError
import app.awrad.core.domain.account.AccountResult
import app.awrad.core.domain.account.InputProblem
import app.awrad.core.network.api.ApiFailure
import app.awrad.core.network.api.ApiResult
import app.awrad.core.network.api.Problem

/** The domain error for an API failure. Problems are told apart by `code` only (STYLE §7). */
internal fun accountErrorOf(failure: ApiFailure): AccountError = when (failure) {
    is ApiFailure.ProblemResponse -> accountErrorOf(failure.problem, failure.retryAfterSeconds)
    ApiFailure.NoConnection -> AccountError.NoConnection
    ApiFailure.NotSignedIn -> AccountError.SessionEnded
    is ApiFailure.UnexpectedResponse -> AccountError.Unexpected
}

internal fun accountErrorOf(problem: Problem, retryAfterSeconds: Long?): AccountError = when (problem.code) {
    "validation_failed" -> AccountError.InvalidInput(problem.errors.mapNotNull { inputProblemOf(it.code) }.toSet())
    "verification_code_invalid" -> AccountError.VerificationCodeInvalid
    "reset_code_invalid" -> AccountError.ResetCodeInvalid
    "invalid_credentials" -> AccountError.InvalidCredentials
    "email_verification_required" -> AccountError.EmailVerificationRequired
    "refresh_token_invalid", "refresh_reuse_detected", "unauthenticated" -> AccountError.SessionEnded
    "rate_limited" -> AccountError.RateLimited(retryAfterSeconds)
    "malformed_request", "idempotency_key_reused", "csrf_token_invalid" -> AccountError.RequestRejected
    else -> AccountError.Unexpected
}

/** Field codes of `validation_failed` (contracts/api `Email`, `Password`). Unknown ones are dropped. */
internal fun inputProblemOf(code: String): InputProblem? = when (code) {
    "email_invalid" -> InputProblem.EMAIL_INVALID
    "password_too_short" -> InputProblem.PASSWORD_TOO_SHORT
    "password_too_long" -> InputProblem.PASSWORD_TOO_LONG
    "password_too_common" -> InputProblem.PASSWORD_TOO_COMMON
    else -> null
}

internal inline fun <T, R> ApiResult<T>.toAccountResult(transform: (T) -> R): AccountResult<R> = when (this) {
    is ApiResult.Success -> AccountResult.Success(transform(value))
    is ApiResult.Failure -> AccountResult.Failure(accountErrorOf(failure))
}
