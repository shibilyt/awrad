package app.awrad.core.network.api

import app.awrad.core.network.IdGenerator
import app.awrad.core.network.http.HttpRequest
import app.awrad.core.network.http.HttpResponse
import app.awrad.core.network.http.HttpTransport
import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import java.io.IOException

/** The app's current language (`en`, `ar` or `ml`), sent as `Accept-Language` where an email may go out. */
public fun interface AppLanguage {
    public fun current(): String
}

/** The JSON settings for the API: unknown response fields are tolerated (STYLE §14), defaults are sent. */
internal val ApiJson: Json = Json {
    ignoreUnknownKeys = true
    encodeDefaults = true
    explicitNulls = true
}

/**
 * Sends one [ApiOperation] and reads its answer; shared by the API classes. Headers follow the operation:
 * a bearer token only on authenticated operations (STYLE §11), a new UUIDv7 `Idempotency-Key` where the spec
 * takes one (§10), and `Accept-Language` where an email may go out. Errors decode as RFC 9457 [Problem]s (§7).
 */
internal class ApiCaller(
    private val transport: HttpTransport,
    private val ids: IdGenerator,
    private val language: AppLanguage,
) {
    /** Sends [body] (null = none). [response] null means the body of a success is ignored (`202`, `204`). */
    suspend fun <B, R> send(
        operation: ApiOperation,
        body: B,
        request: KSerializer<B>?,
        response: KSerializer<R>?,
        options: CallOptions = CallOptions(),
    ): ApiResult<R> {
        val json = request?.let { ApiJson.encodeToString(it, body) }
        return send(operation, json, response, options)
    }

    @Suppress("UNCHECKED_CAST")
    private suspend fun <R> send(
        operation: ApiOperation,
        body: String?,
        response: KSerializer<R>?,
        options: CallOptions,
    ): ApiResult<R> {
        require(operation.isPublic == (options.accessToken == null)) {
            "${operation.operationId}: a bearer token goes on authenticated operations only"
        }
        val headers = buildMap {
            put("Accept", "application/json, application/problem+json")
            options.accessToken?.let { put("Authorization", "Bearer $it") }
            if (operation.idempotent) put("Idempotency-Key", options.idempotencyKey ?: ids.newId())
            if (operation.sendsLanguage) put("Accept-Language", language.current())
        }
        val path = operation.pathWith(options.pathParameters)
        val reply = try {
            transport.execute(HttpRequest(operation.method, path, headers, body, options.query))
        } catch (_: IOException) {
            return ApiResult.Failure(ApiFailure.NoConnection)
        }
        return when {
            reply.status in SUCCESS -> if (response == null) {
                ApiResult.Success(Unit as R)
            } else {
                decode(reply, response)
            }
            else -> ApiResult.Failure(problemOf(reply))
        }
    }

    private fun <R> decode(reply: HttpResponse, serializer: KSerializer<R>): ApiResult<R> = try {
        ApiResult.Success(ApiJson.decodeFromString(serializer, reply.body.orEmpty()))
    } catch (_: SerializationException) {
        ApiResult.Failure(ApiFailure.UnexpectedResponse(reply.status))
    } catch (_: IllegalArgumentException) {
        ApiResult.Failure(ApiFailure.UnexpectedResponse(reply.status))
    }

    private fun problemOf(reply: HttpResponse): ApiFailure {
        val problem = reply.body?.let { body ->
            runCatching { ApiJson.decodeFromString(Problem.serializer(), body) }.getOrNull()
        }
        return if (problem == null) {
            ApiFailure.UnexpectedResponse(reply.status)
        } else {
            ApiFailure.ProblemResponse(problem, reply.header("Retry-After")?.trim()?.toLongOrNull())
        }
    }

    private companion object {
        val SUCCESS = 200..299
    }
}

/**
 * The per-call parts of a request. [idempotencyKey] null means a fresh one (when the operation takes one);
 * [accessToken] must be set exactly for authenticated operations.
 */
internal data class CallOptions(
    val accessToken: String? = null,
    val idempotencyKey: String? = null,
    val pathParameters: Map<String, String> = emptyMap(),
    val query: Map<String, String> = emptyMap(),
) {
    override fun toString(): String = "CallOptions(path=$pathParameters, query=${query.keys})"
}
