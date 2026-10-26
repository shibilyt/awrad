package app.awrad.core.network.http

import kotlinx.coroutines.suspendCancellableCoroutine
import okhttp3.Call
import okhttp3.Callback
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import java.io.IOException
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/** [HttpTransport] over OkHttp (ADR 0005). No interceptors: every header is set by the API client. */
internal class OkHttpTransport(
    baseUrl: String,
    private val client: OkHttpClient = defaultClient(),
) : HttpTransport {

    private val base: HttpUrl = baseUrl.trimEnd('/').toHttpUrl()

    override suspend fun execute(request: HttpRequest): HttpResponse {
        val call = client.newCall(request.toOkHttp())
        return suspendCancellableCoroutine { continuation ->
            continuation.invokeOnCancellation { call.cancel() }
            call.enqueue(
                object : Callback {
                    override fun onFailure(call: Call, e: IOException) {
                        continuation.resumeWithException(e)
                    }

                    override fun onResponse(call: Call, response: Response) {
                        val result = runCatching { response.use { it.toHttpResponse() } }
                        result.fold(continuation::resume, continuation::resumeWithException)
                    }
                },
            )
        }
    }

    private fun HttpRequest.toOkHttp(): Request {
        val url = base.newBuilder()
            .addPathSegments(path.trimStart('/'))
            .apply { query.forEach { (name, value) -> addQueryParameter(name, value) } }
            .build()
        val requestBody = body?.toRequestBody(JSON)
        return Request.Builder()
            .url(url)
            .apply { headers.forEach { (name, value) -> header(name, value) } }
            .method(method.name, requestBody ?: if (method == HttpMethod.POST) EMPTY_BODY else null)
            .build()
    }

    private fun Response.toHttpResponse(): HttpResponse = HttpResponse(
        status = code,
        headers = headers.names().associate { it.lowercase() to headers[it].orEmpty() },
        body = body?.string()?.takeIf { it.isNotEmpty() },
    )

    private companion object {
        val JSON = "application/json; charset=utf-8".toMediaType()
        val EMPTY_BODY = ByteArray(0).toRequestBody(null)
        const val CONNECT_TIMEOUT_SECONDS = 15L
        const val CALL_TIMEOUT_SECONDS = 30L

        fun defaultClient(): OkHttpClient = OkHttpClient.Builder()
            .connectTimeout(CONNECT_TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .callTimeout(CALL_TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .followRedirects(false)
            .build()
    }
}
