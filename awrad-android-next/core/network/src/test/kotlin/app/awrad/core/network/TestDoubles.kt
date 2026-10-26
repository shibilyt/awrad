package app.awrad.core.network

import app.awrad.core.network.http.HttpRequest
import app.awrad.core.network.http.HttpResponse
import app.awrad.core.network.http.HttpTransport
import app.awrad.core.network.session.CredentialStore
import app.awrad.core.network.session.StoredCredentials
import java.io.IOException
import java.util.UUID

/** Answers each request with [respond] (by default per path from [routes]) and records every request. */
internal class FakeTransport : HttpTransport {
    val requests = mutableListOf<HttpRequest>()
    val routes = mutableMapOf<String, suspend (HttpRequest) -> HttpResponse>()

    fun on(path: String, respond: suspend (HttpRequest) -> HttpResponse) {
        routes[path] = respond
    }

    fun requestsTo(path: String): List<HttpRequest> = requests.filter { it.path == path }

    override suspend fun execute(request: HttpRequest): HttpResponse {
        requests += request
        val route = routes[request.path] ?: error("No fake route for ${request.path}")
        return route(request)
    }
}

internal object Responses {
    fun empty(status: Int): HttpResponse = HttpResponse(status)

    fun json(status: Int, body: String, headers: Map<String, String> = emptyMap()): HttpResponse =
        HttpResponse(status, headers.mapKeys { it.key.lowercase() }, body)

    fun problem(status: Int, code: String, headers: Map<String, String> = emptyMap()): HttpResponse = json(
        status,
        """{"type":"urn:awrad:problem:$code","title":"t","status":$status,"code":"$code","detail":"d","errors":[]}""",
        headers,
    )

    fun grant(
        refreshToken: String,
        accessToken: String,
        expiresAt: String = "2026-10-26T08:20:00Z",
        email: String = "amina@example.com",
    ): HttpResponse = json(
        200,
        """
        {"account":{"id":"$ACCOUNT_ID","email":"$email","created_at":"2026-10-26T08:00:00Z"},
         "session":{"id":"9a7d1c42-3e5b-4f60-8a19-0c2d4e6f8b13","device_name":"Pixel 9","platform":"android",
           "created_at":"2026-10-26T08:05:00Z","last_seen_at":"2026-10-26T08:05:00Z",
           "idle_expires_at":"2026-11-25T08:05:00Z","absolute_expires_at":"2027-04-24T08:05:00Z"},
         "access_token":"$accessToken","access_token_expires_at":"$expiresAt","refresh_token":"$refreshToken"}
        """.trimIndent(),
    )

    fun offline(): Nothing = throw IOException("offline")

    const val ACCOUNT_ID = "0b6f6a1e-6c1f-4b8e-9a51-2f3d7c1e8a90"
}

/** [CredentialStore] in memory; a new manager over the same store is an app restart. */
internal class InMemoryCredentialStore(var credentials: StoredCredentials = StoredCredentials()) : CredentialStore {
    private val installation = UUID.randomUUID().toString()

    override suspend fun installationId(): String = installation

    override suspend fun read(): StoredCredentials = credentials

    override suspend fun write(credentials: StoredCredentials) {
        this.credentials = credentials
    }
}
