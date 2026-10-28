package app.awrad.core.domain.sync

import app.awrad.core.domain.AwradId
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.StateFlow
import java.time.Instant

/** Where syncing stands for the active profile, for Settings. */
public data class SyncStatus(
    val state: SyncState = SyncState.SIGNED_OUT,
    val lastSyncedAt: Instant? = null,
    val pendingCount: Int = 0,
)

/** Why the active profile is or isn't syncing. */
public enum class SyncState {
    /** Not signed in: edits are kept on the phone (queued only for an account's profile) and nothing is sent. */
    SIGNED_OUT,

    /** Signed in, but the active profile isn't this account's (for example while the first sign-in asks). */
    WAITING,

    SYNCING,

    /** The last sync finished. */
    IDLE,

    /** The last attempt failed (offline, server fault); it's retried with backoff. */
    RETRYING,

    /** The server said the request was for another account (`409 account_mismatch`). Nothing is sent. */
    ACCOUNT_MISMATCH,
}

/** A conflict as the screens show it: what changed, and whether the local side is a delete. */
public data class OpenConflict(val key: EntityKey, val localOp: SyncOp)

/**
 * Port: the change queue for the active profile. It only ever contacts the server while signed in as the
 * active profile's account (ADR-2026-10-28); signed out, it makes no API calls.
 */
public interface SyncService {
    public val status: StateFlow<SyncStatus>

    /** Open conflicts in the active profile. */
    public val conflicts: Flow<List<OpenConflict>>

    /** Changes the server refused and the phone undid, until the user dismisses them. */
    public val notices: Flow<List<SyncNotice>>

    /** Syncs soon: after the 2-second debounce when [debounced], else now. Does nothing while it may not sync. */
    public fun requestSync(debounced: Boolean = true)

    /** Keep mine or Use theirs for the conflict on [key]. */
    public suspend fun resolve(key: EntityKey, choice: ConflictChoice)

    public suspend fun dismissNotice(notice: SyncNotice)
}

/** A profile as Settings lists it. */
public data class LocalProfile(
    val profileId: AwradId,
    val email: String?,
    val isActive: Boolean,
    val hasUnsent: Boolean,
    val lastUsedAt: Instant?,
)

/** A question waiting for the user, with what it's about. */
public sealed interface PendingProfilePrompt {
    /** The first sign-in as [email] found data made before signing in. */
    public data class AnonymousData(val email: String) : PendingProfilePrompt

    /** [email]'s account no longer exists; its data is still on the phone. */
    public data class AccountDeleted(val profileId: AwradId, val email: String?) : PendingProfilePrompt
}

/**
 * Port: the local profiles (contracts/sync/v1, "Local profiles"). Signing in and out drives it; the screens ask
 * the questions it raises and list the profiles in Settings.
 */
public interface ProfileService {
    /** Every profile on the phone, the active one first, then by last use. */
    public val profiles: Flow<List<LocalProfile>>

    /** The question waiting for an answer, if any. */
    public val prompt: StateFlow<PendingProfilePrompt?>

    /** Answers [prompt]. */
    public suspend fun answer(choice: ProfileChoice)

    /** Whether removing [profileId] needs the unsent-changes warning first. */
    public suspend fun removalPrompt(profileId: AwradId): ProfilePrompt?

    /** Removes [profileId] and its data from the phone. Removing the active one signs out first. */
    public suspend fun remove(profileId: AwradId)
}
