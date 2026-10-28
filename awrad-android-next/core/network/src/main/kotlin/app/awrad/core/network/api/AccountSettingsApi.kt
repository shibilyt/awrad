package app.awrad.core.network.api

import app.awrad.core.network.IdGenerator
import app.awrad.core.network.http.HttpTransport

/**
 * The account settings operations (tag `account_settings`): the sessions list, revoking, changing the
 * password or email, and deleting the account. Every one is authenticated: the caller passes the access
 * token (normally through `DeviceSessionManager.authorized`).
 */
public class AccountSettingsApi(transport: HttpTransport, ids: IdGenerator, language: AppLanguage) {
    private val caller = ApiCaller(transport, ids, language)

    /** One page of sessions; [cursor] is the previous page's `next_cursor`, null for the first. */
    public suspend fun listAccountSessions(accessToken: String, cursor: String? = null): ApiResult<AccountSessionPage> =
        caller.send(
            ApiOperation.LIST_ACCOUNT_SESSIONS,
            Unit,
            null,
            AccountSessionPage.serializer(),
            CallOptions(
                accessToken = accessToken,
                query = buildMap {
                    put("limit", PAGE_SIZE.toString())
                    cursor?.let { put("cursor", it) }
                },
            ),
        )

    public suspend fun revokeAccountSession(accessToken: String, sessionId: String): ApiResult<Unit> =
        caller.send<Unit, Unit>(
            ApiOperation.REVOKE_ACCOUNT_SESSION,
            Unit,
            null,
            null,
            CallOptions(accessToken = accessToken, pathParameters = mapOf("session_id" to sessionId)),
        )

    public suspend fun revokeOtherAccountSessions(accessToken: String): ApiResult<Unit> =
        caller.send<Unit, Unit>(
            ApiOperation.REVOKE_OTHER_ACCOUNT_SESSIONS,
            Unit,
            null,
            null,
            CallOptions(accessToken = accessToken),
        )

    public suspend fun changePassword(accessToken: String, body: ChangePasswordRequest): ApiResult<Unit> =
        caller.send(
            ApiOperation.CHANGE_PASSWORD,
            body,
            ChangePasswordRequest.serializer(),
            null,
            CallOptions(accessToken = accessToken),
        )

    public suspend fun requestEmailChange(accessToken: String, body: RequestEmailChangeRequest): ApiResult<Unit> =
        caller.send(
            ApiOperation.REQUEST_EMAIL_CHANGE,
            body,
            RequestEmailChangeRequest.serializer(),
            null,
            CallOptions(accessToken = accessToken),
        )

    public suspend fun confirmEmailChange(
        accessToken: String,
        body: ConfirmEmailChangeRequest,
    ): ApiResult<AccountResponse> = caller.send(
        ApiOperation.CONFIRM_EMAIL_CHANGE,
        body,
        ConfirmEmailChangeRequest.serializer(),
        AccountResponse.serializer(),
        CallOptions(accessToken = accessToken),
    )

    public suspend fun deleteAccount(accessToken: String, body: CurrentPasswordRequest): ApiResult<Unit> =
        caller.send(
            ApiOperation.DELETE_ACCOUNT,
            body,
            CurrentPasswordRequest.serializer(),
            null,
            CallOptions(accessToken = accessToken),
        )

    private companion object {
        /** The spec's maximum, so an account almost always fits one page. */
        const val PAGE_SIZE = 100
    }
}
