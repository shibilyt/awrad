package app.awrad.core.network.api

import app.awrad.core.network.http.HttpMethod

/**
 * Every API operation the app calls, as declared in `contracts/api/openapi.bundled.json`.
 * ApiContractTest checks each one against the spec: method, path, credential and headers.
 *
 * @property isPublic `security: []`. A public operation never carries a bearer token (STYLE §11).
 * @property sendsLanguage takes `Accept-Language`: the request may send an email in the app's language.
 * @property idempotent takes `Idempotency-Key` (STYLE §10).
 */
public enum class ApiOperation(
    public val operationId: String,
    public val method: HttpMethod,
    public val path: String,
    public val isPublic: Boolean,
    public val sendsLanguage: Boolean,
    public val idempotent: Boolean,
) {
    REGISTER_ACCOUNT("register_account", HttpMethod.POST, "/api/v1/accounts", true, true, true),
    VERIFY_ACCOUNT_EMAIL("verify_account_email", HttpMethod.POST, "/api/v1/accounts/verify_email", true, false, true),
    RESEND_VERIFICATION_CODE(
        "resend_verification_code",
        HttpMethod.POST,
        "/api/v1/accounts/resend_verification_code",
        true,
        true,
        true,
    ),
    REQUEST_PASSWORD_RESET(
        "request_password_reset",
        HttpMethod.POST,
        "/api/v1/accounts/request_password_reset",
        true,
        true,
        true,
    ),
    RESET_PASSWORD("reset_password", HttpMethod.POST, "/api/v1/accounts/reset_password", true, false, true),
    GET_CURRENT_ACCOUNT("get_current_account", HttpMethod.GET, "/api/v1/account", false, false, false),
    CREATE_DEVICE_SESSION("create_device_session", HttpMethod.POST, "/api/v1/device_sessions", true, true, true),
    REFRESH_DEVICE_SESSION(
        "refresh_device_session",
        HttpMethod.POST,
        "/api/v1/device_sessions/refresh",
        true,
        false,
        true,
    ),
    SIGN_OUT_DEVICE_SESSION(
        "sign_out_device_session",
        HttpMethod.POST,
        "/api/v1/device_sessions/sign_out",
        true,
        false,
        true,
    ),
}
