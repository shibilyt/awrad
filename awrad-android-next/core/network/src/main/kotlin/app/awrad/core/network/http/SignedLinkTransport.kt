package app.awrad.core.network.http

import java.io.File

/** How a transfer to or from a signed link ended. */
public sealed interface TransferResult {
    /** The whole file went through. */
    public data object Done : TransferResult

    /** Storage answered with a non-2xx [status] (for example `403` for an expired link). Nothing was transferred. */
    public data class Refused(val status: Int) : TransferResult

    /** No answer, or the connection dropped part-way: offline, timed out, or reset. */
    public data object NoConnection : TransferResult
}

/**
 * Moves recordings straight to and from storage with the signed links `AudioApi` returns, never through the API.
 * No `Authorization` header is ever sent: the link carries its own signature. The only seam to storage: tests use a
 * fake.
 */
public interface SignedLinkTransport {
    /** PUTs [file], unchanged, to [url] with exactly [headers] (all of them, verbatim). */
    public suspend fun upload(url: String, headers: Map<String, String>, file: File): TransferResult

    /** GETs [url] and writes the body to [target], replacing it. [target] is left alone unless the answer is 2xx. */
    public suspend fun download(url: String, target: File): TransferResult
}
