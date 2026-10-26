package app.awrad.core.network.api

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/*
 * Hand-written request and response bodies for the mobile account operations (root ADR-2026-10-16).
 * Field names follow contracts/api/openapi.yaml; ApiContractTest round-trips every spec example through them.
 */

/** `register_account` body. */
@Serializable
public data class RegisterAccountRequest(
    val email: String,
    val password: String,
) {
    override fun toString(): String = "RegisterAccountRequest(email=$email)"
}

/** `verify_account_email` body. */
@Serializable
public data class VerifyAccountEmailRequest(
    val email: String,
    val code: String,
)

/** `EmailOnly`: `resend_verification_code` and `request_password_reset` bodies. */
@Serializable
public data class EmailOnlyRequest(
    val email: String,
)

/** `reset_password` body. */
@Serializable
public data class ResetPasswordRequest(
    val email: String,
    val code: String,
    @SerialName("new_password") val newPassword: String,
) {
    override fun toString(): String = "ResetPasswordRequest(email=$email)"
}

/** `DeviceInfo`. */
@Serializable
public data class DeviceInfo(
    @SerialName("installation_id") val installationId: String,
    val name: String,
    val platform: String,
)

/** `create_device_session` body. */
@Serializable
public data class CreateDeviceSessionRequest(
    val email: String,
    val password: String,
    val device: DeviceInfo,
) {
    override fun toString(): String = "CreateDeviceSessionRequest(email=$email, device=$device)"
}

/** `RefreshTokenOnly`: `refresh_device_session` and `sign_out_device_session` bodies. */
@Serializable
public data class RefreshTokenRequest(
    @SerialName("refresh_token") val refreshToken: String,
) {
    override fun toString(): String = "RefreshTokenRequest(…)"
}

/** `Account`. */
@Serializable
public data class AccountResponse(
    val id: String,
    val email: String,
    @SerialName("created_at") val createdAt: String,
)

/** `DeviceSession`. [platform] is a string so an unknown value doesn't fail decoding (STYLE §3). */
@Serializable
public data class DeviceSessionResponse(
    val id: String,
    @SerialName("device_name") val deviceName: String,
    val platform: String,
    @SerialName("created_at") val createdAt: String,
    @SerialName("last_seen_at") val lastSeenAt: String,
    @SerialName("idle_expires_at") val idleExpiresAt: String,
    @SerialName("absolute_expires_at") val absoluteExpiresAt: String,
)

/** `DeviceSessionGrant`: the result of signing in or refreshing. */
@Serializable
public data class DeviceSessionGrant(
    val account: AccountResponse,
    val session: DeviceSessionResponse,
    @SerialName("access_token") val accessToken: String,
    @SerialName("access_token_expires_at") val accessTokenExpiresAt: String,
    @SerialName("refresh_token") val refreshToken: String,
) {
    override fun toString(): String = "DeviceSessionGrant(account=$account, session=$session)"
}

/** `FieldError`. */
@Serializable
public data class FieldError(
    val field: String,
    val code: String,
    val detail: String,
)

/**
 * RFC 9457 problem details (STYLE §7). Clients switch on [code] only; [title] and [detail] are English,
 * for logs, and never shown. Only [code] is needed to handle a problem, so the rest have defaults.
 */
@Serializable
public data class Problem(
    val type: String = "",
    val title: String = "",
    val status: Int,
    val code: String,
    val detail: String = "",
    val errors: List<FieldError> = emptyList(),
)
