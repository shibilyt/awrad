package app.awrad.core.network.api

import app.awrad.core.network.http.HttpMethod
import java.net.URLEncoder

/**
 * Every API operation the app calls, as declared in `contracts/api/openapi.bundled.json`.
 * ApiContractTest checks each one against the spec: method, path, credential and headers.
 *
 * @property path the spec's path template; [pathWith] fills its `{name}` segments.
 * @property isPublic `security: []`. A public operation never carries a bearer token (STYLE §11).
 * @property sendsLanguage takes `Accept-Language`: the request may send an email in the app's language.
 * @property idempotent takes `Idempotency-Key` (STYLE §10).
 * @property namesAccount takes `X-Awrad-Account`: the account the request's data belongs to (the change queue).
 */
public enum class ApiOperation(
    public val operationId: String,
    public val method: HttpMethod,
    public val path: String,
    public val isPublic: Boolean,
    public val sendsLanguage: Boolean,
    public val idempotent: Boolean,
    public val namesAccount: Boolean = false,
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
    LIST_ACCOUNT_SESSIONS("list_account_sessions", HttpMethod.GET, "/api/v1/account/sessions", false, false, false),
    REVOKE_ACCOUNT_SESSION(
        "revoke_account_session",
        HttpMethod.DELETE,
        "/api/v1/account/sessions/{session_id}",
        false,
        false,
        false,
    ),
    REVOKE_OTHER_ACCOUNT_SESSIONS(
        "revoke_other_account_sessions",
        HttpMethod.POST,
        "/api/v1/account/sessions/revoke_others",
        false,
        false,
        true,
    ),
    CHANGE_PASSWORD("change_password", HttpMethod.POST, "/api/v1/account/change_password", false, true, true),
    REQUEST_EMAIL_CHANGE(
        "request_email_change",
        HttpMethod.POST,
        "/api/v1/account/request_email_change",
        false,
        true,
        true,
    ),
    CONFIRM_EMAIL_CHANGE(
        "confirm_email_change",
        HttpMethod.POST,
        "/api/v1/account/confirm_email_change",
        false,
        true,
        true,
    ),
    DELETE_ACCOUNT("delete_account", HttpMethod.POST, "/api/v1/account/delete", false, true, true),
    POST_SYNC_COMMANDS(
        "post_sync_commands",
        HttpMethod.POST,
        "/api/v1/sync/commands",
        isPublic = false,
        sendsLanguage = false,
        idempotent = true,
        namesAccount = true,
    ),
    LIST_SYNC_CHANGES(
        "list_sync_changes",
        HttpMethod.GET,
        "/api/v1/sync/changes",
        isPublic = false,
        sendsLanguage = false,
        idempotent = false,
        namesAccount = true,
    ),
    ;

    /** [path] with each `{name}` replaced by its URL-encoded value. Fails when one is missing. */
    public fun pathWith(parameters: Map<String, String> = emptyMap()): String =
        PARAMETER.replace(path) { match ->
            val value = requireNotNull(parameters[match.groupValues[1]]) { "$operationId: no ${match.value}" }
            URLEncoder.encode(value, Charsets.UTF_8.name()).replace("+", "%20")
        }

    private companion object {
        val PARAMETER = Regex("""\{([a-z_]+)\}""")
    }
}
