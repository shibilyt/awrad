package app.awrad.core.domain.account

import kotlinx.coroutines.flow.Flow

/**
 * Port: the account and this device's session (contracts/api, tags `accounts` and `device_sessions`).
 * Settings of a signed-in account are [AccountSettingsRepository].
 *
 * Signing in, signing out and a session ending elsewhere never touch local practice data.
 */
public interface AccountRepository {
    /** The current sign-in state, starting from what's stored on the device. */
    public val session: Flow<SignInState>

    /** Creates an account and emails a verification code. Succeeds the same way for an existing email. */
    public suspend fun register(email: EmailAddress, password: String): AccountResult<Unit>

    /** Verifies the email. Doesn't sign in. */
    public suspend fun verifyEmail(email: EmailAddress, code: EmailCode): AccountResult<Unit>

    public suspend fun resendVerificationCode(email: EmailAddress): AccountResult<Unit>

    public suspend fun requestPasswordReset(email: EmailAddress): AccountResult<Unit>

    /** Sets a new password; the server revokes every session of the account. Doesn't sign in. */
    public suspend fun resetPassword(email: EmailAddress, code: EmailCode, newPassword: String): AccountResult<Unit>

    /** Signs this device in, replacing any earlier session of this installation. */
    public suspend fun signIn(email: EmailAddress, password: String): AccountResult<Account>

    /** Reads the signed-in account from the server and updates the stored copy. */
    public suspend fun refreshAccount(): AccountResult<Account>

    /**
     * Signs this device out. Local credentials are always cleared; the server is told now, or later when
     * it can be reached.
     */
    public suspend fun signOut()
}
