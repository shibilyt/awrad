package app.awrad.core.network.api

import app.awrad.core.network.http.HttpTransport

/**
 * The account and device-session operations (tags `accounts` and `device_sessions`). Stateless: tokens are
 * passed in. Public operations get no `Authorization` header; every POST gets an `Idempotency-Key`.
 */
public class AccountsApi(transport: HttpTransport, language: AppLanguage) {
    private val caller = ApiCaller(transport, language)

    public suspend fun registerAccount(body: RegisterAccountRequest): ApiResult<Unit> =
        caller.send(ApiOperation.REGISTER_ACCOUNT, body, RegisterAccountRequest.serializer(), null)

    public suspend fun verifyAccountEmail(body: VerifyAccountEmailRequest): ApiResult<Unit> =
        caller.send(ApiOperation.VERIFY_ACCOUNT_EMAIL, body, VerifyAccountEmailRequest.serializer(), null)

    public suspend fun resendVerificationCode(body: EmailOnlyRequest): ApiResult<Unit> =
        caller.send(ApiOperation.RESEND_VERIFICATION_CODE, body, EmailOnlyRequest.serializer(), null)

    public suspend fun requestPasswordReset(body: EmailOnlyRequest): ApiResult<Unit> =
        caller.send(ApiOperation.REQUEST_PASSWORD_RESET, body, EmailOnlyRequest.serializer(), null)

    public suspend fun resetPassword(body: ResetPasswordRequest): ApiResult<Unit> =
        caller.send(ApiOperation.RESET_PASSWORD, body, ResetPasswordRequest.serializer(), null)

    public suspend fun createDeviceSession(body: CreateDeviceSessionRequest): ApiResult<DeviceSessionGrant> =
        caller.send(
            ApiOperation.CREATE_DEVICE_SESSION,
            body,
            CreateDeviceSessionRequest.serializer(),
            DeviceSessionGrant.serializer(),
        )

    /** [idempotencyKey] is required: a retry of the same refresh must reuse it, or the server sees token reuse. */
    public suspend fun refreshDeviceSession(
        body: RefreshTokenRequest,
        idempotencyKey: String,
    ): ApiResult<DeviceSessionGrant> = caller.send(
        ApiOperation.REFRESH_DEVICE_SESSION,
        body,
        RefreshTokenRequest.serializer(),
        DeviceSessionGrant.serializer(),
        CallOptions(idempotencyKey = idempotencyKey),
    )

    public suspend fun signOutDeviceSession(body: RefreshTokenRequest, idempotencyKey: String): ApiResult<Unit> =
        caller.send<RefreshTokenRequest, Unit>(
            ApiOperation.SIGN_OUT_DEVICE_SESSION,
            body,
            RefreshTokenRequest.serializer(),
            null,
            CallOptions(idempotencyKey = idempotencyKey),
        )

    public suspend fun getCurrentAccount(accessToken: String): ApiResult<AccountResponse> = caller.send(
        ApiOperation.GET_CURRENT_ACCOUNT,
        Unit,
        null,
        AccountResponse.serializer(),
        CallOptions(accessToken = accessToken),
    )
}
