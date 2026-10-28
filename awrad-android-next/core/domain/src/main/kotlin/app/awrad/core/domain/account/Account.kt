package app.awrad.core.domain.account

import app.awrad.core.domain.AwradId

/** A signed-in Awrad account (CONTEXT.md, "Account"). Its email is always verified. */
public data class Account(val id: AwradId, val email: String)

/** Whether this installation is signed in. An account is optional: everything offline works without one. */
public sealed interface SignInState {
    /**
     * [reason] says why, when a session ended while the app was running. [accountId] names a deleted account, so
     * its local profile can be offered for removal.
     */
    public data class SignedOut(
        val reason: SignOutReason = SignOutReason.NOT_SIGNED_IN,
        val accountId: AwradId? = null,
    ) : SignInState

    public data class SignedIn(val account: Account) : SignInState
}

/** Why this installation isn't signed in. Local practice data is untouched in every case. */
public enum class SignOutReason {
    /** It wasn't signed in when the app started. */
    NOT_SIGNED_IN,

    /** The person signed out on this device. */
    SIGNED_OUT,

    /** The server ended this device's session: signed out elsewhere, a password reset, or expiry. */
    SESSION_ENDED,

    /** The account was deleted: from this device, or elsewhere (`account_deleted` on refresh). */
    ACCOUNT_DELETED,
}

/** A field-level reason the input was rejected, by the client's own check or the server's `validation_failed`. */
public enum class InputProblem {
    EMAIL_INVALID,
    PASSWORD_TOO_SHORT,
    PASSWORD_TOO_LONG,

    /** The server's blocklist; clients can't check this one. */
    PASSWORD_TOO_COMMON,

    /** Not 6 digits after normalising. */
    CODE_INVALID,

    /** `current_password_incorrect`: the re-entered password for a sensitive change is wrong. */
    CURRENT_PASSWORD_INCORRECT,

    /** `email_unchanged`: the new email is the account's email already. */
    EMAIL_UNCHANGED,
}

/**
 * Why an account operation failed. Adapters map the API's problem `code` (and only it) to one of these,
 * and the UI maps each to localized text. Unknown codes are [Unexpected].
 */
public sealed interface AccountError {
    /** `validation_failed`, with the field problems the client understands (may be empty). */
    public data class InvalidInput(val problems: Set<InputProblem>) : AccountError

    /** `verification_code_invalid`: wrong, expired or used code, or an unknown email. */
    public data object VerificationCodeInvalid : AccountError

    /** `reset_code_invalid`. */
    public data object ResetCodeInvalid : AccountError

    /** `email_change_code_invalid`: wrong, expired or used code for the new email. */
    public data object EmailChangeCodeInvalid : AccountError

    /** `email_taken`: the new email became another account's before the change was confirmed. */
    public data object EmailTaken : AccountError

    /** `not_found`: the session to revoke has already ended (or never belonged to this account). */
    public data object NotFound : AccountError

    /** `invalid_credentials`: wrong email or password, without saying which. */
    public data object InvalidCredentials : AccountError

    /** `email_verification_required`: the server has emailed a fresh code; go to the code screen. */
    public data object EmailVerificationRequired : AccountError

    /** `refresh_token_invalid`, `refresh_reuse_detected` or `unauthenticated`: this device is signed out. */
    public data object SessionEnded : AccountError

    /** `rate_limited`, with the server's `Retry-After` when it sent one. */
    public data class RateLimited(val retryAfterSeconds: Long?) : AccountError

    /** `malformed_request`, `idempotency_key_reused` and other requests the server can't take from this app. */
    public data object RequestRejected : AccountError

    /** The server couldn't be reached. Nothing changed locally. */
    public data object NoConnection : AccountError

    /** An unknown problem code, a server fault or a response the app can't read. */
    public data object Unexpected : AccountError
}

/** The outcome of an [AccountRepository] operation. */
public sealed interface AccountResult<out T> {
    public data class Success<out T>(val value: T) : AccountResult<T>

    public data class Failure(val error: AccountError) : AccountResult<Nothing>
}
