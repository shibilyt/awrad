package app.awrad.core.testing

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.account.Account
import app.awrad.core.domain.account.AccountRepository
import app.awrad.core.domain.account.AccountResult
import app.awrad.core.domain.account.AccountSession
import app.awrad.core.domain.account.EmailAddress
import app.awrad.core.domain.account.EmailCode
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow

/**
 * Scriptable [AccountRepository]: each operation returns its `…Result` property, and every call is recorded
 * in [calls]. A successful sign-in signs the fake in; signing out always signs it out.
 */
public class FakeAccountRepository(initial: AccountSession = AccountSession.SignedOut) : AccountRepository {
    private val state = MutableStateFlow(initial)

    override val session: Flow<AccountSession> = state

    public val currentSession: AccountSession get() = state.value

    public val calls: MutableList<String> = mutableListOf()

    public var registerResult: AccountResult<Unit> = AccountResult.Success(Unit)
    public var verifyResult: AccountResult<Unit> = AccountResult.Success(Unit)
    public var resendResult: AccountResult<Unit> = AccountResult.Success(Unit)
    public var requestResetResult: AccountResult<Unit> = AccountResult.Success(Unit)
    public var resetResult: AccountResult<Unit> = AccountResult.Success(Unit)
    public var signInResult: AccountResult<Account> = AccountResult.Success(ACCOUNT)
    public var refreshResult: AccountResult<Account> = AccountResult.Success(ACCOUNT)

    override suspend fun register(email: EmailAddress, password: String): AccountResult<Unit> =
        registerResult.also { calls += "register $email" }

    override suspend fun verifyEmail(email: EmailAddress, code: EmailCode): AccountResult<Unit> =
        verifyResult.also { calls += "verify $email $code" }

    override suspend fun resendVerificationCode(email: EmailAddress): AccountResult<Unit> =
        resendResult.also { calls += "resend $email" }

    override suspend fun requestPasswordReset(email: EmailAddress): AccountResult<Unit> =
        requestResetResult.also { calls += "request_reset $email" }

    override suspend fun resetPassword(
        email: EmailAddress,
        code: EmailCode,
        newPassword: String,
    ): AccountResult<Unit> = resetResult.also { calls += "reset $email $code" }

    override suspend fun signIn(email: EmailAddress, password: String): AccountResult<Account> {
        calls += "sign_in $email"
        val result = signInResult
        if (result is AccountResult.Success) state.value = AccountSession.SignedIn(result.value)
        return result
    }

    override suspend fun refreshAccount(): AccountResult<Account> = refreshResult.also { calls += "refresh" }

    override suspend fun signOut() {
        calls += "sign_out"
        state.value = AccountSession.SignedOut
    }

    public companion object {
        public val ACCOUNT: Account = Account(AwradId("0b6f6a1e-6c1f-4b8e-9a51-2f3d7c1e8a90"), "amina@example.com")
    }
}
