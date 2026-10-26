package app.awrad.core.domain.account

import app.awrad.core.domain.AwradId

/**
 * Port: the settings of the signed-in account (contracts/api, tag `account_settings`; slice 2b).
 *
 * Each operation needs a signed-in device. When the server says this device's session has ended, the
 * device is signed out ([SignOutReason.SESSION_ENDED] on [AccountRepository.session]) and the call fails
 * with [AccountError.SessionEnded]. Nothing here touches local practice data.
 */
public interface AccountSettingsRepository {
    /** Every phone and browser signed in to the account, this device included. */
    public suspend fun accountSessions(): AccountResult<List<AccountSession>>

    /** Ends one session. [AccountError.NotFound] when it had already ended. */
    public suspend fun revokeAccountSession(id: AwradId): AccountResult<Unit>

    /** Ends every session except this device's. */
    public suspend fun revokeOtherAccountSessions(): AccountResult<Unit>

    /** Changes the password; every other session ends, this device stays signed in. */
    public suspend fun changePassword(currentPassword: String, newPassword: String): AccountResult<Unit>

    /** Emails a code to [newEmail]. Nothing changes until [confirmEmailChange]; a new request cancels the code. */
    public suspend fun requestEmailChange(currentPassword: String, newEmail: EmailAddress): AccountResult<Unit>

    /** Switches the account to the new email, updates the signed-in account, and returns it. */
    public suspend fun confirmEmailChange(code: EmailCode): AccountResult<Account>

    /**
     * Deletes the account and everything the server keeps for it, now and for good. Every session ends and
     * this device is signed out ([SignOutReason.ACCOUNT_DELETED]); practice data on the device stays.
     */
    public suspend fun deleteAccount(currentPassword: String): AccountResult<Unit>
}
