package app.awrad.core.data.account

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.account.Account
import app.awrad.core.domain.account.AccountRepository
import app.awrad.core.domain.account.AccountResult
import app.awrad.core.domain.account.AccountSession
import app.awrad.core.domain.account.EmailAddress
import app.awrad.core.domain.account.EmailCode
import app.awrad.core.network.api.AccountResponse
import app.awrad.core.network.api.AccountsApi
import app.awrad.core.network.api.ApiResult
import app.awrad.core.network.api.EmailOnlyRequest
import app.awrad.core.network.api.RegisterAccountRequest
import app.awrad.core.network.api.ResetPasswordRequest
import app.awrad.core.network.api.VerifyAccountEmailRequest
import app.awrad.core.network.session.DeviceSessionManager
import app.awrad.core.network.session.DeviceSessionState
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.mapNotNull
import javax.inject.Inject

/** [AccountRepository] over the API and this installation's [DeviceSessionManager]. */
internal class NetworkAccountRepository @Inject constructor(
    private val api: AccountsApi,
    private val sessions: DeviceSessionManager,
) : AccountRepository {

    override val session: Flow<AccountSession> = sessions.state
        .mapNotNull { state ->
            when (state) {
                DeviceSessionState.Loading -> null
                DeviceSessionState.SignedOut -> AccountSession.SignedOut
                is DeviceSessionState.SignedIn -> AccountSession.SignedIn(account(state.accountId, state.email))
            }
        }
        .distinctUntilChanged()

    override suspend fun register(email: EmailAddress, password: String): AccountResult<Unit> =
        api.registerAccount(RegisterAccountRequest(email.value, password)).toAccountResult { }

    override suspend fun verifyEmail(email: EmailAddress, code: EmailCode): AccountResult<Unit> =
        api.verifyAccountEmail(VerifyAccountEmailRequest(email.value, code.value)).toAccountResult { }

    override suspend fun resendVerificationCode(email: EmailAddress): AccountResult<Unit> =
        api.resendVerificationCode(EmailOnlyRequest(email.value)).toAccountResult { }

    override suspend fun requestPasswordReset(email: EmailAddress): AccountResult<Unit> =
        api.requestPasswordReset(EmailOnlyRequest(email.value)).toAccountResult { }

    override suspend fun resetPassword(
        email: EmailAddress,
        code: EmailCode,
        newPassword: String,
    ): AccountResult<Unit> =
        api.resetPassword(ResetPasswordRequest(email.value, code.value, newPassword)).toAccountResult { }

    override suspend fun signIn(email: EmailAddress, password: String): AccountResult<Account> =
        sessions.signIn(email.value, password).toAccountResult { account(it.account) }

    override suspend fun refreshAccount(): AccountResult<Account> {
        val result = sessions.authorized { token -> api.getCurrentAccount(token) }
        if (result is ApiResult.Success) sessions.updateAccount(result.value)
        return result.toAccountResult(::account)
    }

    override suspend fun signOut() {
        sessions.signOut()
    }

    private fun account(response: AccountResponse): Account = account(response.id, response.email)

    private fun account(id: String, email: String): Account = Account(AwradId(id), email)
}
