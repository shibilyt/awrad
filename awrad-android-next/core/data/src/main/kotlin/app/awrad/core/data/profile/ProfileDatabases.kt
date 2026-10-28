package app.awrad.core.data.profile

import app.awrad.core.database.AwradDatabase
import app.awrad.core.database.ProfileEntity
import app.awrad.core.database.RegistryDao
import app.awrad.core.database.RegistryEntity
import app.awrad.core.domain.AwradId
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.onStart
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.File
import java.time.Clock
import java.time.Duration
import java.util.concurrent.ConcurrentHashMap

/** The active profile's open database and private files. [accountId] is null for the anonymous profile. */
internal data class OpenProfile(
    val profileId: AwradId,
    val accountId: AwradId?,
    val database: AwradDatabase,
    val filesDir: File,
)

/** Opens, closes and deletes the profiles' own databases and files. Tests open them in memory. */
internal interface ProfileStorage {
    fun open(profileId: AwradId): AwradDatabase

    fun filesDir(profileId: AwradId): File

    /** Closes a database [open] returned. */
    fun release(database: AwradDatabase)

    /** Deletes the profile's database and files. Its database is already closed. */
    fun delete(profileId: AwradId)
}

/**
 * Which profile is active, and its open database (contracts/sync/v1, "Local profiles"). Every write to a profile
 * goes through [write], which runs it in one Room transaction and is serialized with switching profiles, so a
 * write never lands in a profile that's no longer active. Observers follow [active]: a switch emits the new
 * profile, and the old database closes once they've moved over.
 */
internal class ProfileDatabases(
    private val registry: RegistryDao,
    private val storage: ProfileStorage,
    private val clock: Clock,
    private val newId: () -> AwradId,
    private val scope: CoroutineScope,
    private val io: CoroutineDispatcher,
    /** How long an old database stays open after a switch, for observers still moving to the new one. */
    private val closeDelay: Duration = Duration.ofSeconds(2),
) {
    private val mutex = Mutex()
    private val mutableActive = MutableStateFlow<OpenProfile?>(null)
    private val closing = ConcurrentHashMap<AwradId, Job>()

    /** The active profile, opened on first collection. */
    val active: Flow<OpenProfile> = mutableActive.onStart { current() }.filterNotNull()

    /** The active profile, opening it (and making the first, anonymous profile) if needed. */
    suspend fun current(): OpenProfile = mutex.withLock { currentLocked() }

    /**
     * Runs [block] in one transaction of the active profile's database, if it's still [expected] (any profile when
     * null). Returns null when another profile became active meanwhile.
     */
    suspend fun <T> write(expected: AwradId? = null, block: (OpenProfile) -> T): T? = mutex.withLock {
        val profile = currentLocked()
        if (expected != null && profile.profileId != expected) return@withLock null
        withContext(io) { profile.database.runInTransaction<T> { block(profile) } }
    }

    /** Runs [block] in one transaction of [profileId]'s database, active or not. */
    suspend fun <T> writeTo(profileId: AwradId, block: (OpenProfile) -> T): T = mutex.withLock {
        val active = currentLocked()
        if (active.profileId == profileId) {
            withContext(io) { active.database.runInTransaction<T> { block(active) } }
        } else {
            withContext(io) {
                val database = storage.open(profileId)
                try {
                    val entry = registry.profiles().first { it.profileId == profileId.value }
                    val accountId = entry.accountId?.let(::AwradId)
                    val profile = OpenProfile(profileId, accountId, database, storage.filesDir(profileId))
                    database.runInTransaction<T> { block(profile) }
                } finally {
                    storage.release(database)
                }
            }
        }
    }

    /** Makes [profileId] active: opens it, closes the old one, and records when it was last used. */
    suspend fun activate(profileId: AwradId): Unit = mutex.withLock {
        val old = currentLocked()
        withContext(io) {
            registry.upsertRegistry(RegistryEntity(activeProfileId = profileId.value))
            registry.profiles().firstOrNull { it.profileId == profileId.value }?.let {
                registry.upsertProfile(it.copy(lastUsedAt = clock.millis()))
            }
        }
        if (old.profileId == profileId) {
            refreshLocked(old)
        } else {
            mutableActive.value = openLocked(profileId)
            closeLater(old)
        }
    }

    /** Re-reads the active profile's account (after it's adopted by an account). */
    suspend fun refresh(): Unit = mutex.withLock { refreshLocked(currentLocked()) }

    /** Deletes [profileId]'s database and files, once it's closed. It must not be the active profile. */
    suspend fun erase(profileId: AwradId) {
        mutex.withLock { check(currentLocked().profileId != profileId) { "Can't erase the active profile" } }
        val pendingClose = closing.remove(profileId)
        scope.launch(io) {
            pendingClose?.join()
            storage.delete(profileId)
        }
    }

    private suspend fun currentLocked(): OpenProfile {
        mutableActive.value?.let { return it }
        val activeId = withContext(io) {
            registry.registry()?.activeProfileId?.let(::AwradId) ?: createAnonymousLocked()
        }
        return openLocked(activeId).also { mutableActive.value = it }
    }

    /** The first profile on a new install: anonymous, until the first sign-in. */
    private suspend fun createAnonymousLocked(): AwradId {
        val id = newId()
        val now = clock.millis()
        registry.replace(
            profiles = registry.profiles() + ProfileEntity(id.value, null, null, 0, createdAt = now, lastUsedAt = now),
            registry = RegistryEntity(activeProfileId = id.value),
        )
        return id
    }

    private suspend fun openLocked(profileId: AwradId): OpenProfile = withContext(io) {
        val entry = registry.profiles().firstOrNull { it.profileId == profileId.value }
        OpenProfile(profileId, entry?.accountId?.let(::AwradId), storage.open(profileId), storage.filesDir(profileId))
    }

    private suspend fun refreshLocked(profile: OpenProfile) {
        val entry = withContext(io) { registry.profiles().firstOrNull { it.profileId == profile.profileId.value } }
        mutableActive.value = profile.copy(accountId = entry?.accountId?.let(::AwradId))
    }

    private fun closeLater(profile: OpenProfile) {
        closing[profile.profileId] = scope.launch(io) {
            delay(closeDelay.toMillis())
            storage.release(profile.database)
        }
    }
}
