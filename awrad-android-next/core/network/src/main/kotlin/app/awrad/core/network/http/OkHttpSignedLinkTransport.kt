package app.awrad.core.network.http

import kotlinx.coroutines.suspendCancellableCoroutine
import okhttp3.Call
import okhttp3.Callback
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.Response
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume

/**
 * [SignedLinkTransport] over OkHttp with its own client: the files are far bigger than API bodies, so the timeouts
 * are longer. No interceptors, no `Authorization`, and redirects aren't followed.
 */
internal class OkHttpSignedLinkTransport(
    private val client: OkHttpClient = defaultClient(),
) : SignedLinkTransport {

    override suspend fun upload(url: String, headers: Map<String, String>, file: File): TransferResult =
        transfer(uploadRequest(url, headers, file)) { response ->
            if (response.isSuccessful) TransferResult.Done else TransferResult.Refused(response.code)
        }

    override suspend fun download(url: String, target: File): TransferResult =
        transfer(downloadRequest(url)) { response ->
            val body = response.body
            if (response.isSuccessful && body != null) {
                saveAtomically(body.byteStream(), target)
                TransferResult.Done
            } else {
                TransferResult.Refused(response.code)
            }
        }

    /** Runs [request] and maps its response with [handle]; an [IOException], also mid-body, is [NoConnection]. */
    private suspend fun transfer(request: Request, handle: (Response) -> TransferResult): TransferResult =
        suspendCancellableCoroutine { continuation ->
            val call = client.newCall(request)
            continuation.invokeOnCancellation { call.cancel() }
            call.enqueue(
                object : Callback {
                    override fun onFailure(call: Call, e: IOException) {
                        continuation.resume(TransferResult.NoConnection)
                    }

                    override fun onResponse(call: Call, response: Response) {
                        val result = try {
                            response.use(handle)
                        } catch (_: IOException) {
                            TransferResult.NoConnection
                        }
                        continuation.resume(result)
                    }
                },
            )
        }

    /** Writes next to [target] first, so a dropped connection never leaves half a file under its name. */
    private fun saveAtomically(source: InputStream, target: File) {
        val partial = File(target.absoluteFile.parentFile, "${target.name}.part")
        try {
            source.use { input -> partial.outputStream().use { output -> input.copyTo(output) } }
            Files.move(partial.toPath(), target.toPath(), StandardCopyOption.REPLACE_EXISTING)
        } finally {
            partial.delete()
        }
    }

    private companion object {
        const val CONNECT_TIMEOUT_SECONDS = 15L
        const val IO_TIMEOUT_SECONDS = 60L
        const val CALL_TIMEOUT_MINUTES = 5L

        fun defaultClient(): OkHttpClient = OkHttpClient.Builder()
            .connectTimeout(CONNECT_TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .readTimeout(IO_TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .writeTimeout(IO_TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .callTimeout(CALL_TIMEOUT_MINUTES, TimeUnit.MINUTES)
            .followRedirects(false)
            .build()
    }
}

/**
 * The PUT for a signed upload link: exactly [headers], verbatim, and [file] as the body. The body's media type is the
 * `content-type` header's value as given, so OkHttp sends that header unchanged and adds no charset.
 */
internal fun uploadRequest(url: String, headers: Map<String, String>, file: File): Request {
    val contentType = headers.entries.firstOrNull { it.key.equals("content-type", ignoreCase = true) }?.value
    return Request.Builder()
        .url(url)
        .apply { headers.forEach { (name, value) -> header(name, value) } }
        .put(file.asRequestBody(contentType?.toMediaTypeOrNull()))
        .build()
}

/** The GET for a signed download link: no header of ours at all. */
internal fun downloadRequest(url: String): Request = Request.Builder().url(url).get().build()
