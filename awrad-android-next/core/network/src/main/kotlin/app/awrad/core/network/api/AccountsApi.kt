package app.awrad.core.network.api

import app.awrad.core.network.http.HttpRequest
import app.awrad.core.network.http.HttpResponse
import app.awrad.core.network.http.HttpTransport
import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import java.io.IOException
import java.util.UUID

/** The app's current language (`en`, `ar` or `ml`), sent as `Accept-Language` where an email may go out. */
public fun interface AppLanguage {
    public fun current(): String
}

/** The JSON settings for the API: unknown response fields are tolerated (STYLE §14), defaults are sent. */
internal val ApiJson: Json = Json {
    ignoreUnknownKeys = true
    encodeDefaults = true
    explicitNulls = true
}

/**
 * The account and device-session operations (tags `accounts` and `device_sessions`). Stateless: tokens are
 * passed in. Public operations get no `Authorization` header; every POST gets an `Idempotency-Key`.
 */
public class AccountsApi(
    private val transport: HttpTransport,
    private val language: AppLanguage,
) {
    public suspend fun registerAccount(body: RegisterAccountRequest): ApiResult<Unit> =
        call(ApiOperation.REGISTER_ACCOUNT, body, RegisterAccountRequest.serializer())

    public suspend fun verifyAccountEmail(body: VerifyAccountEmailRequest): ApiResult<Unit> =
        call(ApiOperation.VERIFY_ACCOUNT_EMAIL, body, VerifyAccountEmailRequest.serializer())

    public suspend fun resendVerificationCode(body: EmailOnlyRequest): ApiResult<Unit> =
        call(ApiOperation.RESEND_VERIFICATION_CODE, body, EmailOnlyRequest.serializer())

    public suspend fun requestPasswordReset(body: EmailOnlyRequest): ApiResult<Unit> =
        call(ApiOperation.REQUEST_PASSWORD_RESET, body, EmailOnlyRequest.serializer())

    public suspend fun resetPassword(body: ResetPasswordRequest): ApiResult<Unit> =
        call(ApiOperation.RESET_PASSWORD, body, ResetPasswordRequest.serializer())

    public suspend fun createDeviceSession(body: CreateDeviceSessionRequest): ApiResult<DeviceSessionGrant> =
        call(
            ApiOperation.CREATE_DEVICE_SESSION,
            body,
            CreateDeviceSessionRequest.serializer(),
            DeviceSessionGrant.serializer(),
        )

    /** [idempotencyKey] is required: a retry of the same refresh must reuse it, or the server sees token reuse. */
    public suspend fun refreshDeviceSession(
        body: RefreshTokenRequest,
        idempotencyKey: String,
    ): ApiResult<DeviceSessionGrant> = call(
        ApiOperation.REFRESH_DEVICE_SESSION,
        body,
        RefreshTokenRequest.serializer(),
        DeviceSessionGrant.serializer(),
        idempotencyKey = idempotencyKey,
    )

    public suspend fun signOutDeviceSession(body: RefreshTokenRequest, idempotencyKey: String): ApiResult<Unit> =
        call(
            ApiOperation.SIGN_OUT_DEVICE_SESSION,
            body,
            RefreshTokenRequest.serializer(),
            idempotencyKey = idempotencyKey,
        )

    public suspend fun getCurrentAccount(accessToken: String): ApiResult<AccountResponse> = send(
        operation = ApiOperation.GET_CURRENT_ACCOUNT,
        body = null,
        response = AccountResponse.serializer(),
        accessToken = accessToken,
        idempotencyKey = null,
    )

    private suspend fun <B> call(
        operation: ApiOperation,
        body: B,
        request: KSerializer<B>,
        idempotencyKey: String = newIdempotencyKey(),
    ): ApiResult<Unit> = send(operation, ApiJson.encodeToString(request, body), null, null, idempotencyKey)

    private suspend fun <B, R> call(
        operation: ApiOperation,
        body: B,
        request: KSerializer<B>,
        response: KSerializer<R>,
        idempotencyKey: String = newIdempotencyKey(),
    ): ApiResult<R> = send(operation, ApiJson.encodeToString(request, body), response, null, idempotencyKey)

    /** [response] null means the body of a success is ignored (`202`, `204`). */
    @Suppress("UNCHECKED_CAST")
    private suspend fun <R> send(
        operation: ApiOperation,
        body: String?,
        response: KSerializer<R>?,
        accessToken: String?,
        idempotencyKey: String?,
    ): ApiResult<R> {
        require(operation.isPublic == (accessToken == null)) {
            "${operation.operationId}: a bearer token goes on authenticated operations only"
        }
        val headers = buildMap {
            put("Accept", "application/json, application/problem+json")
            if (accessToken != null) put("Authorization", "Bearer $accessToken")
            if (operation.idempotent && idempotencyKey != null) put("Idempotency-Key", idempotencyKey)
            if (operation.sendsLanguage) put("Accept-Language", language.current())
        }
        val reply = try {
            transport.execute(HttpRequest(operation.method, operation.path, headers, body))
        } catch (_: IOException) {
            return ApiResult.Failure(ApiFailure.NoConnection)
        }
        return when {
            reply.status in SUCCESS -> if (response == null) {
                ApiResult.Success(Unit as R)
            } else {
                decode(reply, response)
            }
            else -> ApiResult.Failure(problemOf(reply))
        }
    }

    private fun <R> decode(reply: HttpResponse, serializer: KSerializer<R>): ApiResult<R> = try {
        ApiResult.Success(ApiJson.decodeFromString(serializer, reply.body.orEmpty()))
    } catch (_: SerializationException) {
        ApiResult.Failure(ApiFailure.UnexpectedResponse(reply.status))
    } catch (_: IllegalArgumentException) {
        ApiResult.Failure(ApiFailure.UnexpectedResponse(reply.status))
    }

    private fun problemOf(reply: HttpResponse): ApiFailure {
        val problem = reply.body?.let { body ->
            runCatching { ApiJson.decodeFromString(Problem.serializer(), body) }.getOrNull()
        }
        return if (problem == null) {
            ApiFailure.UnexpectedResponse(reply.status)
        } else {
            ApiFailure.ProblemResponse(problem, reply.header("Retry-After")?.trim()?.toLongOrNull())
        }
    }

    private fun newIdempotencyKey(): String = UUID.randomUUID().toString()

    private companion object {
        val SUCCESS = 200..299
    }
}
