package app.awrad.core.network.api

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/*
 * Hand-written bodies for the account settings operations (tag `account_settings`, slice 2b). Field names
 * follow contracts/api/paths/account_settings.yaml; ApiContractTest round-trips every spec example.
 */

/**
 * `AccountSession`: one place the account is signed in. [kind] and [platform] are strings so an unknown
 * value doesn't fail decoding (STYLE §3). [name] is null when the server couldn't tell (a browser).
 */
@Serializable
public data class AccountSessionResponse(
    val id: String,
    val kind: String,
    val name: String?,
    val platform: String,
    @SerialName("created_at") val createdAt: String,
    @SerialName("last_seen_at") val lastSeenAt: String,
    @SerialName("is_current") val isCurrent: Boolean,
)

/** `list_account_sessions` response: one page. [nextCursor] is null on the last page. */
@Serializable
public data class AccountSessionPage(
    val items: List<AccountSessionResponse>,
    @SerialName("next_cursor") val nextCursor: String?,
)

/** `change_password` body. */
@Serializable
public data class ChangePasswordRequest(
    @SerialName("current_password") val currentPassword: String,
    @SerialName("new_password") val newPassword: String,
) {
    override fun toString(): String = "ChangePasswordRequest(…)"
}

/** `request_email_change` body. */
@Serializable
public data class RequestEmailChangeRequest(
    @SerialName("current_password") val currentPassword: String,
    @SerialName("new_email") val newEmail: String,
) {
    override fun toString(): String = "RequestEmailChangeRequest(newEmail=$newEmail)"
}

/** `confirm_email_change` body. */
@Serializable
public data class ConfirmEmailChangeRequest(
    val code: String,
)

/** `delete_account` body. */
@Serializable
public data class CurrentPasswordRequest(
    @SerialName("current_password") val currentPassword: String,
) {
    override fun toString(): String = "CurrentPasswordRequest(…)"
}
