package app.awrad.core.domain.account

import app.awrad.core.domain.AwradId
import java.time.Instant

/**
 * One place the account is signed in (CONTEXT.md, "Account session"): a phone's device session or a
 * browser session. [name] is the device model or a browser summary, or null when the server couldn't tell.
 */
public data class AccountSession(
    val id: AwradId,
    val kind: Kind,
    val name: String?,
    val platform: Platform,
    val createdAt: Instant,
    val lastSeenAt: Instant,
    /** The session of this device. */
    val isCurrent: Boolean,
) {
    public enum class Kind {
        DEVICE,
        BROWSER,

        /** A kind this version of the app doesn't know (STYLE §3). */
        OTHER,
    }

    public enum class Platform {
        ANDROID,
        IOS,
        WEB,

        /** A platform this version of the app doesn't know (STYLE §3). */
        OTHER,
    }
}

/** The order the list shows: this device first, then the most recently used. */
public fun List<AccountSession>.inListOrder(): List<AccountSession> =
    sortedWith(compareByDescending<AccountSession> { it.isCurrent }.thenByDescending { it.lastSeenAt })
