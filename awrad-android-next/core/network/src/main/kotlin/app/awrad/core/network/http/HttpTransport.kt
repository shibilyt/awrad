package app.awrad.core.network.http

import java.io.IOException

/** An HTTP method the API uses (STYLE §2). */
public enum class HttpMethod { GET, POST, PUT, DELETE }

/** One request, relative to the API base URL. [body] is UTF-8 JSON. */
public data class HttpRequest(
    val method: HttpMethod,
    val path: String,
    val headers: Map<String, String> = emptyMap(),
    val body: String? = null,
) {
    override fun toString(): String = "HttpRequest($method $path, headers=${headers.keys})"
}

/** One response. Header names are lowercase. */
public data class HttpResponse(
    val status: Int,
    val headers: Map<String, String> = emptyMap(),
    val body: String? = null,
) {
    public fun header(name: String): String? = headers[name.lowercase()]
}

/**
 * Sends requests to the API. The only seam between the client and the network: tests use a fake.
 */
public fun interface HttpTransport {
    /** Throws [IOException] when no response arrived (offline, timeout, connection reset). */
    @Throws(IOException::class)
    public suspend fun execute(request: HttpRequest): HttpResponse
}
