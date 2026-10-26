package app.awrad.core.network.api

import app.awrad.core.network.FakeTransport
import app.awrad.core.network.Responses
import app.awrad.core.network.http.HttpMethod
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class AccountsApiTest {

    private val transport = FakeTransport()
    private val api = AccountsApi(transport) { "ar" }
    private val settings = AccountSettingsApi(transport) { "ar" }

    private fun ApiOperation.testPath(): String = pathWith(mapOf("session_id" to SESSION_ID))

    /** Calls each [ApiOperation] once. */
    private suspend fun callEveryOperation() {
        val token = "access-token-0123456789"
        settings.listAccountSessions(token)
        settings.revokeAccountSession(token, SESSION_ID)
        settings.revokeOtherAccountSessions(token)
        settings.changePassword(token, ChangePasswordRequest("a long passphrase", "another long passphrase"))
        settings.requestEmailChange(token, RequestEmailChangeRequest("a long passphrase", "amina.new@example.com"))
        settings.confirmEmailChange(token, ConfirmEmailChangeRequest("519274"))
        settings.deleteAccount(token, CurrentPasswordRequest("a long passphrase"))
        api.registerAccount(RegisterAccountRequest("amina@example.com", "a long passphrase"))
        api.verifyAccountEmail(VerifyAccountEmailRequest("amina@example.com", "482913"))
        api.resendVerificationCode(EmailOnlyRequest("amina@example.com"))
        api.requestPasswordReset(EmailOnlyRequest("amina@example.com"))
        api.resetPassword(ResetPasswordRequest("amina@example.com", "730158", "another long passphrase"))
        api.createDeviceSession(
            CreateDeviceSessionRequest(
                "amina@example.com",
                "a long passphrase",
                DeviceInfo("5f0c3b52-8d2e-4e57-9f0a-6b1d2c3e4f50", "Pixel 9", "android"),
            ),
        )
        api.refreshDeviceSession(RefreshTokenRequest("refresh-token-0123456789"), "key-1")
        api.signOutDeviceSession(RefreshTokenRequest("refresh-token-0123456789"), "key-2")
        api.getCurrentAccount("access-token-0123456789")
    }

    @Test
    fun `public operations never carry a bearer token and the authenticated one does`() = runTest {
        ApiOperation.entries.forEach { op -> transport.on(op.testPath()) { Responses.problem(500, "x") } }

        callEveryOperation()

        assertEquals(ApiOperation.entries.size, transport.requests.size)
        ApiOperation.entries.forEach { operation ->
            val request = transport.requestsTo(operation.testPath()).single()
            assertEquals(operation.method, request.method)
            if (operation.isPublic) {
                assertNull(request.headers["Authorization"], operation.operationId)
            } else {
                assertEquals("Bearer access-token-0123456789", request.headers["Authorization"])
            }
        }
    }

    @Test
    fun `language and idempotency headers go where the spec takes them`() = runTest {
        ApiOperation.entries.forEach { op -> transport.on(op.testPath()) { Responses.empty(204) } }

        callEveryOperation()

        ApiOperation.entries.forEach { operation ->
            val request = transport.requestsTo(operation.testPath()).single()
            assertEquals(if (operation.sendsLanguage) "ar" else null, request.headers["Accept-Language"])
            assertEquals(operation.idempotent, request.headers["Idempotency-Key"] != null, operation.operationId)
            if (operation.method == HttpMethod.POST) assertNotNull(request.headers["Idempotency-Key"])
        }
        val refresh = transport.requestsTo(ApiOperation.REFRESH_DEVICE_SESSION.path).single()
        assertEquals("key-1", refresh.headers["Idempotency-Key"])
    }

    @Test
    fun `each call gets a fresh idempotency key`() = runTest {
        transport.on(ApiOperation.REGISTER_ACCOUNT.path) { Responses.empty(202) }

        repeat(2) { api.registerAccount(RegisterAccountRequest("amina@example.com", "a long passphrase")) }

        val keys = transport.requests.map { it.headers.getValue("Idempotency-Key") }
        assertEquals(2, keys.toSet().size)
    }

    @Test
    fun `a problem response is decoded with its code and Retry-After`() = runTest {
        transport.on(ApiOperation.REGISTER_ACCOUNT.path) {
            Responses.problem(429, "rate_limited", mapOf("Retry-After" to "30"))
        }

        val result = api.registerAccount(RegisterAccountRequest("amina@example.com", "a long passphrase"))

        val failure = (result as ApiResult.Failure).failure as ApiFailure.ProblemResponse
        assertEquals("rate_limited", failure.problem.code)
        assertEquals(30L, failure.retryAfterSeconds)
    }

    @Test
    fun `unknown problem members and response fields are tolerated`() = runTest {
        transport.on(ApiOperation.GET_CURRENT_ACCOUNT.path) {
            Responses.json(200, """{"id":"i","email":"e","created_at":"2026-10-26T08:00:00Z","nickname":"n"}""")
        }

        val result = api.getCurrentAccount("access-token-0123456789")

        assertEquals("e", (result as ApiResult.Success).value.email)
    }

    @Test
    fun `no response is NoConnection and an unreadable one is UnexpectedResponse`() = runTest {
        transport.on(ApiOperation.REGISTER_ACCOUNT.path) { Responses.offline() }
        transport.on(ApiOperation.GET_CURRENT_ACCOUNT.path) { Responses.json(502, "<html>bad gateway</html>") }

        val offline = api.registerAccount(RegisterAccountRequest("amina@example.com", "a long passphrase"))
        val proxy = api.getCurrentAccount("access-token-0123456789")

        assertEquals(ApiResult.Failure(ApiFailure.NoConnection), offline)
        assertEquals(ApiResult.Failure(ApiFailure.UnexpectedResponse(502)), proxy)
    }

    @Test
    fun `secrets stay out of toString`() {
        val text = listOf(
            RegisterAccountRequest("amina@example.com", "a long passphrase"),
            ResetPasswordRequest("amina@example.com", "730158", "another long passphrase"),
            RefreshTokenRequest("refresh-token-0123456789"),
            ChangePasswordRequest("a long passphrase", "another long passphrase"),
            RequestEmailChangeRequest("a long passphrase", "amina.new@example.com"),
            CurrentPasswordRequest("a long passphrase"),
        ).joinToString()

        assertFalse("passphrase" in text)
        assertFalse("refresh-token" in text)
        assertTrue("amina@example.com" in text)
        assertTrue("amina.new@example.com" in text)
    }

    @Test
    fun `the session list asks for full pages and passes the cursor back`() = runTest {
        val path = ApiOperation.LIST_ACCOUNT_SESSIONS.path
        transport.on(path) { Responses.json(200, """{"items":[],"next_cursor":null}""") }

        settings.listAccountSessions("access-token-0123456789")
        settings.listAccountSessions("access-token-0123456789", cursor = "c2lnbmVk")

        val (first, second) = transport.requestsTo(path)
        assertEquals(mapOf("limit" to "100"), first.query)
        assertEquals(mapOf("limit" to "100", "cursor" to "c2lnbmVk"), second.query)
        assertNull(first.body)
    }

    @Test
    fun `a session without a name decodes, and revoking puts its id in the path`() = runTest {
        transport.on(ApiOperation.LIST_ACCOUNT_SESSIONS.path) {
            Responses.json(
                200,
                """{"items":[{"id":"$SESSION_ID","kind":"browser","name":null,"platform":"web",
                   "created_at":"2026-10-20T18:00:00Z","last_seen_at":"2026-10-26T21:15:00Z","is_current":false}],
                   "next_cursor":null}""",
            )
        }
        transport.on("/api/v1/account/sessions/$SESSION_ID") { Responses.empty(204) }

        val page = (settings.listAccountSessions("access-token-0123456789") as ApiResult.Success).value
        val revoked = settings.revokeAccountSession("access-token-0123456789", page.items.single().id)

        assertNull(page.items.single().name)
        assertEquals(ApiResult.Success(Unit), revoked)
        assertEquals(HttpMethod.DELETE, transport.requests.last().method)
    }

    private companion object {
        const val SESSION_ID = "4c2e8f10-7b3a-4d5e-9f61-2a8b0c1d3e45"
    }
}
