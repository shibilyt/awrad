package app.awrad.core.network.api

/** The outcome of one API call. */
public sealed interface ApiResult<out T> {
    public data class Success<out T>(val value: T) : ApiResult<T>

    public data class Failure(val failure: ApiFailure) : ApiResult<Nothing>
}

/** Why an API call failed. */
public sealed interface ApiFailure {
    /** An `application/problem+json` response. [retryAfterSeconds] is the `Retry-After` header, if any. */
    public data class ProblemResponse(val problem: Problem, val retryAfterSeconds: Long?) : ApiFailure {
        val status: Int get() = problem.status
    }

    /** No response: offline, timed out, or the connection dropped. Nothing is known about the server side. */
    public data object NoConnection : ApiFailure

    /** A response the client can't read: an unexpected status or body (for example a proxy's HTML page). */
    public data class UnexpectedResponse(val status: Int) : ApiFailure

    /** The operation needs a signed-in device, and this one isn't. */
    public data object NotSignedIn : ApiFailure
}

/** Maps a success value, keeping a failure as it is. */
public inline fun <T, R> ApiResult<T>.map(transform: (T) -> R): ApiResult<R> = when (this) {
    is ApiResult.Success -> ApiResult.Success(transform(value))
    is ApiResult.Failure -> this
}
