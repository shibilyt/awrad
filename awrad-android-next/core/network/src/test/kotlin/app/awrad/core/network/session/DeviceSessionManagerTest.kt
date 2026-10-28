package app.awrad.core.network.session

import app.awrad.core.network.FakeTransport
import app.awrad.core.network.InMemoryCredentialStore
import app.awrad.core.network.Responses
import app.awrad.core.network.SequentialIds
import app.awrad.core.network.api.AccountsApi
import app.awrad.core.network.api.ApiFailure
import app.awrad.core.network.api.ApiOperation
import app.awrad.core.network.api.ApiResult
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class DeviceSessionManagerTest {

    private val refreshPath = ApiOperation.REFRESH_DEVICE_SESSION.path
    private val signOutPath = ApiOperation.SIGN_OUT_DEVICE_SESSION.path
    private val accountPath = ApiOperation.GET_CURRENT_ACCOUNT.path

    private val transport = FakeTransport()
    private val store = InMemoryCredentialStore(
        StoredCredentials(session = StoredSession("refresh-1", Responses.ACCOUNT_ID, "amina@example.com")),
    )
    private var now: Instant = Instant.parse("2026-10-26T08:10:00Z")
    private val clock = object : Clock() {
        override fun instant(): Instant = now
        override fun getZone() = ZoneOffset.UTC
        override fun withZone(zone: java.time.ZoneId?) = this
    }
    private var keys = 0

    /** A new manager over the same store is an app restart: no access token in memory. */
    private fun restart() = DeviceSessionManager(
        api = AccountsApi(transport, SequentialIds()) { "en" },
        store = store,
        deviceName = "Google Pixel 9",
        clock = clock,
    ) { "key-${++keys}" }

    private val manager = restart()

    @Test
    fun `concurrent callers share one refresh`() = runTest {
        val gate = CompletableDeferred<Unit>()
        transport.on(refreshPath) {
            gate.await()
            Responses.grant(refreshToken = "refresh-2", accessToken = "access-2")
        }

        val callers = List(5) { async { manager.accessToken(stale = null) } }
        gate.complete(Unit)
        val tokens = callers.awaitAll()

        assertEquals(1, transport.requestsTo(refreshPath).size)
        assertTrue(tokens.all { it == ApiResult.Success("access-2") })
        assertEquals("refresh-2", store.credentials.session?.refreshToken)
    }

    @Test
    fun `a network error keeps the tokens and the retry reuses the idempotency key`() = runTest {
        transport.on(refreshPath) { Responses.offline() }

        val first = manager.accessToken(stale = null)

        assertEquals(ApiResult.Failure(ApiFailure.NoConnection), first)
        assertEquals("refresh-1", store.credentials.session?.refreshToken)
        assertTrue(manager.state.first() is DeviceSessionState.SignedIn)

        transport.on(refreshPath) { Responses.grant(refreshToken = "refresh-2", accessToken = "access-2") }
        val second = restart().accessToken(stale = null)

        assertEquals(ApiResult.Success("access-2"), second)
        val keysSent = transport.requestsTo(refreshPath).map { it.headers["Idempotency-Key"] }
        assertEquals(listOf("key-1", "key-1"), keysSent)
        assertNull(store.credentials.session?.pendingRefreshKey)
    }

    @Test
    fun `server faults and rate limits keep the tokens`() = runTest {
        for (status in listOf(500, 503, 429)) {
            transport.on(refreshPath) { Responses.problem(status, "rate_limited") }

            manager.accessToken(stale = null)

            assertEquals("refresh-1", store.credentials.session?.refreshToken, "status $status")
        }
        assertEquals(1, transport.requestsTo(refreshPath).map { it.headers["Idempotency-Key"] }.toSet().size)
    }

    @Test
    fun `a 401 from refresh signs the device out`() = runTest {
        for (code in listOf("refresh_token_invalid", "refresh_reuse_detected")) {
            store.credentials = StoredCredentials(StoredSession("refresh-1", Responses.ACCOUNT_ID, "a@b.co"))
            val manager = restart()
            transport.on(refreshPath) { Responses.problem(401, code) }

            val result = manager.accessToken(stale = null)

            assertEquals(401, ((result as ApiResult.Failure).failure as ApiFailure.ProblemResponse).status)
            assertNull(store.credentials.session, code)
            assertEquals(DeviceSessionState.SignedOut(SignOutCause.SESSION_ENDED), manager.state.first())
        }
    }

    @Test
    fun `a session revoked elsewhere signs the device out on its next call, keeping nothing queued`() = runTest {
        transport.on(refreshPath) {
            if (transport.requestsTo(refreshPath).size == 1) {
                Responses.grant(refreshToken = "refresh-2", accessToken = "access-2")
            } else {
                Responses.problem(401, "refresh_token_invalid")
            }
        }
        transport.on(accountPath) { Responses.problem(401, "unauthenticated") }
        manager.accessToken(stale = null)
        val api = AccountsApi(transport, SequentialIds()) { "en" }

        val result = manager.authorized { token -> api.getCurrentAccount(token) }

        assertEquals(401, ((result as ApiResult.Failure).failure as ApiFailure.ProblemResponse).status)
        assertEquals(DeviceSessionState.SignedOut(SignOutCause.SESSION_ENDED), manager.state.first())
        assertEquals(StoredCredentials(), store.credentials)
        assertEquals(ApiResult.Failure(ApiFailure.NotSignedIn), manager.accessToken(stale = null))
    }

    @Test
    fun `a deleted account forgets the session without a sign-out call`() = runTest {
        transport.on(refreshPath) { Responses.grant(refreshToken = "refresh-2", accessToken = "access-2") }
        manager.accessToken(stale = null)

        manager.accountDeleted()

        assertEquals(DeviceSessionState.SignedOut(SignOutCause.ACCOUNT_DELETED), manager.state.first())
        assertEquals(StoredCredentials(), store.credentials)
        assertEquals(listOf(refreshPath), transport.requests.map { it.path })
        assertEquals(ApiResult.Failure(ApiFailure.NotSignedIn), manager.accessToken(stale = null))
    }

    @Test
    fun `a 401 on an authorized call refreshes once and retries`() = runTest {
        transport.on(refreshPath) {
            val count = transport.requestsTo(refreshPath).size
            Responses.grant(refreshToken = "refresh-${count + 1}", accessToken = "access-${count + 1}")
        }
        transport.on(accountPath) { request ->
            if (request.headers["Authorization"] == "Bearer access-2") {
                Responses.problem(401, "unauthenticated")
            } else {
                Responses.json(200, """{"id":"${Responses.ACCOUNT_ID}","email":"x@y.co","created_at":"t"}""")
            }
        }
        val api = AccountsApi(transport, SequentialIds()) { "en" }

        val result = manager.authorized { token -> api.getCurrentAccount(token) }

        assertTrue(result is ApiResult.Success)
        assertEquals(2, transport.requestsTo(refreshPath).size)
        val bearers = transport.requestsTo(accountPath).map { it.headers["Authorization"] }
        assertEquals(listOf("Bearer access-2", "Bearer access-3"), bearers)
    }

    @Test
    fun `an access token close to expiry is refreshed first`() = runTest {
        transport.on(refreshPath) { Responses.grant(refreshToken = "refresh-2", accessToken = "access-2") }
        manager.accessToken(stale = null)
        transport.on(refreshPath) { Responses.grant(refreshToken = "refresh-3", accessToken = "access-3") }

        assertEquals(ApiResult.Success("access-2"), manager.accessToken(stale = null))
        now = Instant.parse("2026-10-26T08:19:45Z")
        assertEquals(ApiResult.Success("access-3"), manager.accessToken(stale = null))
    }

    @Test
    fun `sign-in stores the refresh token only and signs in`() = runTest {
        store.credentials = StoredCredentials()
        val manager = restart()
        transport.on(ApiOperation.CREATE_DEVICE_SESSION.path) {
            Responses.grant(refreshToken = "refresh-9", accessToken = "access-9")
        }

        manager.signIn("amina@example.com", "a long passphrase")

        assertEquals(StoredSession("refresh-9", Responses.ACCOUNT_ID, "amina@example.com"), store.credentials.session)
        assertEquals(DeviceSessionState.SignedIn(Responses.ACCOUNT_ID, "amina@example.com"), manager.state.first())
        assertEquals(ApiResult.Success("access-9"), manager.accessToken(stale = null))
        val body = transport.requests.single().body.orEmpty()
        assertTrue(""""installation_id":"${store.installationId()}"""" in body)
        assertTrue(""""name":"Google Pixel 9","platform":"android"""" in body)
    }

    @Test
    fun `sign-out after a restart revokes with the refresh token`() = runTest {
        transport.on(signOutPath) { Responses.empty(204) }

        restart().signOut()

        val request = transport.requests.single()
        assertEquals(signOutPath, request.path)
        assertNull(request.headers["Authorization"])
        assertEquals("""{"refresh_token":"refresh-1"}""", request.body)
        assertEquals(StoredCredentials(), store.credentials)
    }

    @Test
    fun `sign-out offline clears local credentials and retries later with the same key`() = runTest {
        transport.on(signOutPath) { Responses.offline() }

        manager.signOut()

        assertNull(store.credentials.session)
        assertEquals(DeviceSessionState.SignedOut(SignOutCause.SIGNED_OUT), manager.state.first())
        assertEquals(listOf(PendingSignOut("refresh-1", "key-1")), store.credentials.pendingSignOuts)

        transport.on(signOutPath) { Responses.empty(204) }
        restart().retryPendingSignOuts()

        assertEquals(listOf("key-1", "key-1"), transport.requestsTo(signOutPath).map { it.headers["Idempotency-Key"] })
        assertEquals(StoredCredentials(), store.credentials)
    }

    @Test
    fun `a signed-out device makes no calls for a token`() = runTest {
        store.credentials = StoredCredentials()

        val result = restart().accessToken(stale = null)

        assertEquals(ApiResult.Failure(ApiFailure.NotSignedIn), result)
        assertTrue(transport.requests.isEmpty())
    }
}
