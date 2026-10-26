package app.awrad.core.testing

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.account.Account
import app.awrad.core.domain.account.AccountResult
import app.awrad.core.domain.account.AccountSession
import app.awrad.core.domain.account.AccountSettingsRepository
import app.awrad.core.domain.account.EmailAddress
import app.awrad.core.domain.account.EmailCode
import app.awrad.core.domain.account.SignOutReason
import java.time.Instant

/**
 * Scriptable [AccountSettingsRepository] beside [accounts], whose session it changes like the real one: a
 * confirmed email change updates the signed-in account, and a deletion signs out with
 * [SignOutReason.ACCOUNT_DELETED]. Each call is recorded in [calls].
 */
public class FakeAccountSettingsRepository(
    private val accounts: FakeAccountRepository,
) : AccountSettingsRepository {

    public val calls: MutableList<String> = mutableListOf()

    public var sessionsResult: AccountResult<List<AccountSession>> = AccountResult.Success(SESSIONS)
    public var revokeResult: AccountResult<Unit> = AccountResult.Success(Unit)
    public var revokeOthersResult: AccountResult<Unit> = AccountResult.Success(Unit)
    public var changePasswordResult: AccountResult<Unit> = AccountResult.Success(Unit)
    public var requestEmailChangeResult: AccountResult<Unit> = AccountResult.Success(Unit)
    public var confirmEmailChangeResult: AccountResult<Account> =
        AccountResult.Success(FakeAccountRepository.ACCOUNT.copy(email = NEW_EMAIL))
    public var deleteResult: AccountResult<Unit> = AccountResult.Success(Unit)

    override suspend fun accountSessions(): AccountResult<List<AccountSession>> =
        sessionsResult.also { calls += "sessions" }

    override suspend fun revokeAccountSession(id: AwradId): AccountResult<Unit> =
        revokeResult.also { calls += "revoke ${id.value}" }

    override suspend fun revokeOtherAccountSessions(): AccountResult<Unit> =
        revokeOthersResult.also { calls += "revoke_others" }

    override suspend fun changePassword(currentPassword: String, newPassword: String): AccountResult<Unit> =
        changePasswordResult.also { calls += "change_password" }

    override suspend fun requestEmailChange(currentPassword: String, newEmail: EmailAddress): AccountResult<Unit> =
        requestEmailChangeResult.also { calls += "request_email_change $newEmail" }

    override suspend fun confirmEmailChange(code: EmailCode): AccountResult<Account> {
        calls += "confirm_email_change $code"
        val result = confirmEmailChangeResult
        if (result is AccountResult.Success) accounts.updateAccount(result.value)
        return result
    }

    override suspend fun deleteAccount(currentPassword: String): AccountResult<Unit> {
        calls += "delete_account"
        val result = deleteResult
        if (result is AccountResult.Success) accounts.endSession(SignOutReason.ACCOUNT_DELETED)
        return result
    }

    public companion object {
        public const val NEW_EMAIL: String = "amina.new@example.com"

        /** This phone, and a browser elsewhere whose name the server couldn't tell. */
        public val SESSIONS: List<AccountSession> = listOf(
            AccountSession(
                id = AwradId("9a7d1c42-3e5b-4f60-8a19-0c2d4e6f8b13"),
                kind = AccountSession.Kind.DEVICE,
                name = "Google Pixel 9",
                platform = AccountSession.Platform.ANDROID,
                createdAt = Instant.parse("2026-10-26T08:05:00Z"),
                lastSeenAt = Instant.parse("2026-10-27T06:40:00Z"),
                isCurrent = true,
            ),
            AccountSession(
                id = AwradId("4c2e8f10-7b3a-4d5e-9f61-2a8b0c1d3e45"),
                kind = AccountSession.Kind.BROWSER,
                name = null,
                platform = AccountSession.Platform.WEB,
                createdAt = Instant.parse("2026-10-20T18:00:00Z"),
                lastSeenAt = Instant.parse("2026-10-26T21:15:00Z"),
                isCurrent = false,
            ),
        )
    }
}
