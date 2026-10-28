package app.awrad.core.network.session

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** The signed-in device session as kept on the device. Never holds the access token (memory only). */
@Serializable
internal data class StoredSession(
    @SerialName("refresh_token") val refreshToken: String,
    @SerialName("account_id") val accountId: String,
    val email: String,
    /**
     * The `Idempotency-Key` of a refresh that got no answer. The next try of that refresh reuses it, so a
     * rotation the server already did is replayed instead of looking like token reuse.
     */
    @SerialName("pending_refresh_key") val pendingRefreshKey: String? = null,
) {
    override fun toString(): String = "StoredSession(accountId=$accountId)"
}

/** A sign-out the server hasn't confirmed yet. Retried until it gets an answer. */
@Serializable
internal data class PendingSignOut(
    @SerialName("refresh_token") val refreshToken: String,
    @SerialName("idempotency_key") val idempotencyKey: String,
) {
    override fun toString(): String = "PendingSignOut(…)"
}

/** Everything about accounts that persists, stored as one encrypted document. */
@Serializable
internal data class StoredCredentials(
    val session: StoredSession? = null,
    @SerialName("pending_sign_outs") val pendingSignOuts: List<PendingSignOut> = emptyList(),
)

/** Secure storage for the installation id and the credentials. The Keystore adapter is the real one. */
internal interface CredentialStore {
    /** This installation's UUIDv7, created on first use and kept until the app is uninstalled. */
    suspend fun installationId(): String

    suspend fun read(): StoredCredentials

    suspend fun write(credentials: StoredCredentials)
}
