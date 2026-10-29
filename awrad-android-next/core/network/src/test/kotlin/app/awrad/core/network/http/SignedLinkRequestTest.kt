package app.awrad.core.network.http

import okio.Buffer
import java.io.File
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertNull

class SignedLinkRequestTest {

    private val url = "https://example-account.r2.cloudflarestorage.com/awrad/asset?X-Amz-Signature=abc%2Fdef"
    private val headers = mapOf(
        "content-type" to "audio/mpeg",
        "x-amz-checksum-sha256" to "eVllD5+mm2J5s2lOJQYFnLZwYswPfprSejRlKNNB5bw=",
    )

    private fun recording(): File = File.createTempFile("recording", ".mp3").apply {
        deleteOnExit()
        writeBytes(byteArrayOf(1, 2, 3, 4, 5))
    }

    @Test
    fun `an upload is a PUT of the file to the link with exactly the given headers`() {
        val file = recording()

        val request = uploadRequest(url, headers, file)

        assertEquals("PUT", request.method)
        assertEquals(url, request.url.toString())
        assertEquals(headers, request.headers.toMultimap().mapValues { it.value.single() })
        assertNull(request.header("Authorization"))
        val buffer = Buffer()
        request.body!!.writeTo(buffer)
        assertContentEquals(file.readBytes(), buffer.readByteArray())
        assertEquals(file.length(), request.body!!.contentLength())
    }

    @Test
    fun `the body's media type is the content-type header's value, with no charset`() {
        val request = uploadRequest(url, headers + ("content-type" to "audio/mp4"), recording())

        assertEquals("audio/mp4", request.body!!.contentType().toString())
        assertEquals("audio/mp4", request.header("content-type"))
    }

    @Test
    fun `a download is a bare GET`() {
        val request = downloadRequest(url)

        assertEquals("GET", request.method)
        assertEquals(url, request.url.toString())
        assertEquals(emptyMap(), request.headers.toMultimap())
        assertNull(request.body)
    }
}
