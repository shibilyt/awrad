package app.awrad.core.data.account

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.account.AccountSession
import app.awrad.core.network.api.AccountSessionResponse
import java.time.Instant
import java.time.format.DateTimeParseException

/**
 * The domain session for an `AccountSession`. Unknown `kind` and `platform` values become `OTHER`
 * (STYLE §3); an unreadable timestamp makes the whole response unreadable (null).
 */
internal fun accountSessionOf(response: AccountSessionResponse): AccountSession? {
    val createdAt = instantOf(response.createdAt)
    val lastSeenAt = instantOf(response.lastSeenAt)
    if (createdAt == null || lastSeenAt == null) return null
    return AccountSession(
        id = AwradId(response.id),
        kind = when (response.kind) {
            "device" -> AccountSession.Kind.DEVICE
            "browser" -> AccountSession.Kind.BROWSER
            else -> AccountSession.Kind.OTHER
        },
        name = response.name?.trim()?.takeIf { it.isNotEmpty() },
        platform = when (response.platform) {
            "android" -> AccountSession.Platform.ANDROID
            "ios" -> AccountSession.Platform.IOS
            "web" -> AccountSession.Platform.WEB
            else -> AccountSession.Platform.OTHER
        },
        createdAt = createdAt,
        lastSeenAt = lastSeenAt,
        isCurrent = response.isCurrent,
    )
}

private fun instantOf(value: String): Instant? = try {
    Instant.parse(value)
} catch (_: DateTimeParseException) {
    null
}
