package app.awrad.core.network.session

import app.awrad.core.network.api.AccountResponse
import app.awrad.core.network.api.AccountsApi
import app.awrad.core.network.api.ApiFailure
import app.awrad.core.network.api.ApiResult
import app.awrad.core.network.api.CreateDeviceSessionRequest
import app.awrad.core.network.api.DeviceInfo
import app.awrad.core.network.api.DeviceSessionGrant
import app.awrad.core.network.api.RefreshTokenRequest
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.filterNot
import kotlinx.coroutines.flow.onStart
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.time.format.DateTimeParseException
import java.util.UUID

/** Whether this installation holds a device session. */
public sealed interface DeviceSessionState {
    public data object Loading : DeviceSessionState

    /** [cause] is why the last session ended while the app ran; [SignOutCause.NOT_SIGNED_IN] at start. */
    public data class SignedOut(val cause: SignOutCause) : DeviceSessionState

    public data class SignedIn(val accountId: String, val email: String) : DeviceSessionState
}

/** Why this installation has no device session. Kept in memory only. */
public enum class SignOutCause {
    /** It had none when the app started. */
    NOT_SIGNED_IN,

    /** The person signed out on this device. */
    SIGNED_OUT,

    /** The server ended it: revoked from another device, a password reset, idle expiry or token reuse. */
    SESSION_ENDED,

    /** The account was deleted from this device. */
    ACCOUNT_DELETED,
}

/**
 * This installation's device session (ADR-2026-07-12, ADR-2026-10-26; ARCHITECTURE.md, "Accounts and
 * device sessions").
 *
 * - The refresh token lives in the [CredentialStore]; the access token only in memory.
 * - At most one refresh runs at a time ([mutex]); callers that wait get its result.
 * - Tokens survive network errors and server faults. Only a `401` from refresh drops them.
 * - Sign-out revokes with the refresh token, so it works after a restart, and is retried until the server
 *   answers. Local credentials are cleared straight away. Nothing here touches practice data.
 */
public class DeviceSessionManager internal constructor(
    private val api: AccountsApi,
    private val store: CredentialStore,
    private val deviceName: String,
    private val clock: Clock,
    private val newKey: () -> String = { UUID.randomUUID().toString() },
) {
    private val mutex = Mutex()
    private val mutableState = MutableStateFlow<DeviceSessionState>(DeviceSessionState.Loading)

    /** Guarded by [mutex]. */
    private var access: AccessToken? = null

    /** The session, loaded from storage on first collection (without waiting for a refresh in flight). */
    public val state: Flow<DeviceSessionState> = mutableState
        .onStart { load() }
        .filterNot { it == DeviceSessionState.Loading }

    /** Signs in with `create_device_session`. Replaces any session this installation had. */
    public suspend fun signIn(email: String, password: String): ApiResult<DeviceSessionGrant> {
        retryPendingSignOuts()
        val device = DeviceInfo(installationId = store.installationId(), name = deviceName, platform = PLATFORM)
        val result = api.createDeviceSession(CreateDeviceSessionRequest(email, password, device))
        if (result is ApiResult.Success) mutex.withLock { acceptGrantLocked(store.read(), result.value) }
        return result
    }

    /**
     * Runs an authenticated [call] with a valid access token, refreshing first when needed. On a `401` it
     * refreshes once (unless another caller already did) and retries once.
     */
    public suspend fun <T> authorized(call: suspend (accessToken: String) -> ApiResult<T>): ApiResult<T> =
        when (val token = accessToken(stale = null)) {
            is ApiResult.Failure -> token
            is ApiResult.Success -> {
                val result = call(token.value)
                if (result.isUnauthorized()) callAgain(stale = token.value, call) else result
            }
        }

    private suspend fun <T> callAgain(
        stale: String,
        call: suspend (accessToken: String) -> ApiResult<T>,
    ): ApiResult<T> =
        when (val renewed = accessToken(stale = stale)) {
            is ApiResult.Success -> call(renewed.value)
            is ApiResult.Failure -> renewed
        }

    /** Stores what `get_current_account` returned for the signed-in account. */
    public suspend fun updateAccount(account: AccountResponse): Unit = mutex.withLock {
        val credentials = store.read()
        val session = credentials.session ?: return@withLock
        if (session.accountId != account.id) return@withLock
        store.write(credentials.copy(session = session.copy(email = account.email)))
        mutableState.value = DeviceSessionState.SignedIn(account.id, account.email)
    }

    /**
     * Signs this device out: local credentials are cleared now, and the session is revoked on the server
     * with its refresh token, now or by a later [retryPendingSignOuts].
     */
    public suspend fun signOut() {
        mutex.withLock {
            load()
            val credentials = store.read()
            val session = credentials.session ?: return@withLock
            // Queued before anything else, so a crash or no network still revokes it later.
            val pending = PendingSignOut(session.refreshToken, newKey())
            store.write(StoredCredentials(session = null, pendingSignOuts = credentials.pendingSignOuts + pending))
            access = null
            mutableState.value = DeviceSessionState.SignedOut(SignOutCause.SIGNED_OUT)
        }
        retryPendingSignOuts()
    }

    /**
     * Forgets the session after `delete_account` succeeded. The server has already ended every session, so
     * nothing is queued; practice data isn't touched.
     */
    public suspend fun accountDeleted(): Unit = mutex.withLock {
        load()
        endLocked(SignOutCause.ACCOUNT_DELETED)
    }

    private suspend fun endLocked(cause: SignOutCause) {
        val credentials = store.read()
        store.write(credentials.copy(session = null))
        access = null
        mutableState.value = DeviceSessionState.SignedOut(cause)
    }

    /**
     * Sends every queued `sign_out_device_session`. A sign-out is done once the server answers (it's always
     * `204`, also for a token it doesn't know); without an answer it stays queued.
     */
    public suspend fun retryPendingSignOuts() {
        val pending = mutex.withLock { store.read().pendingSignOuts }
        for (signOut in pending) {
            val result = api.signOutDeviceSession(RefreshTokenRequest(signOut.refreshToken), signOut.idempotencyKey)
            if (!result.isAnswered()) return
            mutex.withLock {
                val credentials = store.read()
                store.write(credentials.copy(pendingSignOuts = credentials.pendingSignOuts - signOut))
            }
        }
    }

    /** A valid access token: the held one, unless it's [stale] or expiring, else a fresh one from a refresh. */
    internal suspend fun accessToken(stale: String?): ApiResult<String> = mutex.withLock {
        load()
        val held = access
        if (held != null && held.token != stale && held.isValidAt(clock.instant())) {
            ApiResult.Success(held.token)
        } else {
            refreshLocked()
        }
    }

    private suspend fun refreshLocked(): ApiResult<String> {
        val credentials = store.read()
        val session = credentials.session ?: return ApiResult.Failure(ApiFailure.NotSignedIn)
        val key = session.pendingRefreshKey ?: newKey().also { key ->
            store.write(credentials.copy(session = session.copy(pendingRefreshKey = key)))
        }
        return when (val result = api.refreshDeviceSession(RefreshTokenRequest(session.refreshToken), key)) {
            is ApiResult.Success -> {
                acceptGrantLocked(store.read(), result.value)
                ApiResult.Success(result.value.accessToken)
            }
            is ApiResult.Failure -> {
                handleRefreshFailureLocked(result.failure)
                result
            }
        }
    }

    private suspend fun handleRefreshFailureLocked(failure: ApiFailure) {
        val status = (failure as? ApiFailure.ProblemResponse)?.status ?: return
        val credentials = store.read()
        when {
            // The session is gone (expired, revoked, or reuse detected): this device is signed out.
            status == UNAUTHORIZED -> endLocked(SignOutCause.SESSION_ENDED)
            // A server fault or rate limit may not have run the refresh: keep the key for the retry.
            status >= SERVER_ERROR || status == TOO_MANY_REQUESTS -> Unit
            // Any other answer (a rejected key or body) won't change on a retry with the same key.
            else -> store.write(credentials.copy(session = credentials.session?.copy(pendingRefreshKey = null)))
        }
    }

    private suspend fun acceptGrantLocked(credentials: StoredCredentials, grant: DeviceSessionGrant) {
        val session = StoredSession(grant.refreshToken, grant.account.id, grant.account.email)
        store.write(credentials.copy(session = session))
        access = AccessToken(grant.accessToken, parseInstant(grant.accessTokenExpiresAt))
        mutableState.value = DeviceSessionState.SignedIn(grant.account.id, grant.account.email)
    }

    /** Sets the first state from storage, unless a sign-in, refresh or sign-out already set one. */
    private suspend fun load() {
        if (mutableState.value != DeviceSessionState.Loading) return
        val session = store.read().session
        val stored = if (session == null) {
            DeviceSessionState.SignedOut(SignOutCause.NOT_SIGNED_IN)
        } else {
            DeviceSessionState.SignedIn(session.accountId, session.email)
        }
        mutableState.compareAndSet(DeviceSessionState.Loading, stored)
    }

    /** An unreadable expiry counts as expired, so the next call refreshes. */
    private fun parseInstant(value: String): Instant = try {
        Instant.parse(value)
    } catch (_: DateTimeParseException) {
        Instant.MIN
    }

    private class AccessToken(val token: String, val expiresAt: Instant) {
        fun isValidAt(now: Instant): Boolean = now.plus(EXPIRY_MARGIN).isBefore(expiresAt)

        override fun toString(): String = "AccessToken(expiresAt=$expiresAt)"
    }

    private companion object {
        const val PLATFORM = "android"
        const val UNAUTHORIZED = 401
        const val TOO_MANY_REQUESTS = 429
        const val SERVER_ERROR = 500

        /** Refresh a little before expiry, so a request doesn't arrive with a token that just ran out. */
        val EXPIRY_MARGIN: Duration = Duration.ofSeconds(30)

        fun ApiResult<*>.isUnauthorized(): Boolean =
            this is ApiResult.Failure && (failure as? ApiFailure.ProblemResponse)?.status == UNAUTHORIZED

        /** The server answered, so retrying the same sign-out won't change anything. */
        fun ApiResult<*>.isAnswered(): Boolean = when (this) {
            is ApiResult.Success -> true
            is ApiResult.Failure -> (failure as? ApiFailure.ProblemResponse)?.status
                .let { status -> status != null && status < SERVER_ERROR && status != TOO_MANY_REQUESTS }
        }
    }
}
