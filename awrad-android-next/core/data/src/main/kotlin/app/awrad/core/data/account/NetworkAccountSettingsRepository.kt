package app.awrad.core.data.account

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.account.Account
import app.awrad.core.domain.account.AccountError
import app.awrad.core.domain.account.AccountResult
import app.awrad.core.domain.account.AccountSession
import app.awrad.core.domain.account.AccountSettingsRepository
import app.awrad.core.domain.account.EmailAddress
import app.awrad.core.domain.account.EmailCode
import app.awrad.core.network.api.AccountSessionPage
import app.awrad.core.network.api.AccountSettingsApi
import app.awrad.core.network.api.ApiResult
import app.awrad.core.network.api.ChangePasswordRequest
import app.awrad.core.network.api.ConfirmEmailChangeRequest
import app.awrad.core.network.api.CurrentPasswordRequest
import app.awrad.core.network.api.RequestEmailChangeRequest
import app.awrad.core.network.session.DeviceSessionManager
import javax.inject.Inject

/**
 * [AccountSettingsRepository] over the API. Every call goes through [DeviceSessionManager.authorized], so a
 * session that ended elsewhere signs the device out (a `401` from refresh).
 */
internal class NetworkAccountSettingsRepository @Inject constructor(
    private val api: AccountSettingsApi,
    private val sessions: DeviceSessionManager,
) : AccountSettingsRepository {

    /** Follows `next_cursor` to the end; an account rarely has more than one page. */
    override suspend fun accountSessions(): AccountResult<List<AccountSession>> {
        val pages = mutableListOf<AccountSessionPage>()
        var cursor: String? = null
        do {
            when (val result = sessions.authorized { token -> api.listAccountSessions(token, cursor) }) {
                is ApiResult.Success -> {
                    pages += result.value
                    cursor = result.value.nextCursor
                }
                is ApiResult.Failure -> return AccountResult.Failure(accountErrorOf(result.failure))
            }
        } while (cursor != null && pages.size < MAX_PAGES)
        val all = pages.flatMap { it.items }.map(::accountSessionOf)
        return if (null in all) {
            AccountResult.Failure(AccountError.Unexpected)
        } else {
            AccountResult.Success(all.filterNotNull())
        }
    }

    override suspend fun revokeAccountSession(id: AwradId): AccountResult<Unit> =
        sessions.authorized { token -> api.revokeAccountSession(token, id.value) }.toAccountResult { }

    override suspend fun revokeOtherAccountSessions(): AccountResult<Unit> =
        sessions.authorized { token -> api.revokeOtherAccountSessions(token) }.toAccountResult { }

    override suspend fun changePassword(currentPassword: String, newPassword: String): AccountResult<Unit> =
        sessions.authorized { token ->
            api.changePassword(token, ChangePasswordRequest(currentPassword, newPassword))
        }.toAccountResult { }

    override suspend fun requestEmailChange(currentPassword: String, newEmail: EmailAddress): AccountResult<Unit> =
        sessions.authorized { token ->
            api.requestEmailChange(token, RequestEmailChangeRequest(currentPassword, newEmail.value))
        }.toAccountResult { }

    override suspend fun confirmEmailChange(code: EmailCode): AccountResult<Account> {
        val result = sessions.authorized { token ->
            api.confirmEmailChange(token, ConfirmEmailChangeRequest(code.value))
        }
        if (result is ApiResult.Success) sessions.updateAccount(result.value)
        return result.toAccountResult(::accountOf)
    }

    /** The server has ended every session by the time it answers, so the device forgets its own. */
    override suspend fun deleteAccount(currentPassword: String): AccountResult<Unit> {
        val result = sessions.authorized { token ->
            api.deleteAccount(token, CurrentPasswordRequest(currentPassword))
        }
        if (result is ApiResult.Success) sessions.accountDeleted()
        return result.toAccountResult { }
    }

    private companion object {
        /** A guard against a server that never ends the list; 10 pages of 100 is far beyond any account. */
        const val MAX_PAGES = 10
    }
}
