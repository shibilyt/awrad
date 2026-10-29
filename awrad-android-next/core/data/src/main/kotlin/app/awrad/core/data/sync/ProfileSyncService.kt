package app.awrad.core.data.sync

import app.awrad.core.data.profile.ProfileDatabases
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.account.AccountRepository
import app.awrad.core.domain.account.SignInState
import app.awrad.core.domain.sync.ApplyChanges
import app.awrad.core.domain.sync.ConflictChoice
import app.awrad.core.domain.sync.EntityKey
import app.awrad.core.domain.sync.EntityType
import app.awrad.core.domain.sync.OpenConflict
import app.awrad.core.domain.sync.RejectionCode
import app.awrad.core.domain.sync.SyncNotice
import app.awrad.core.domain.sync.SyncService
import app.awrad.core.domain.sync.SyncState
import app.awrad.core.domain.sync.SyncStatus
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import java.io.File
import java.time.Clock
import java.time.Instant

/**
 * [SyncService] for the active profile: its status, conflicts and notices follow the active profile's database,
 * and requests go to the [SyncScheduler]. Resolving a conflict is a local write (queued for the next run).
 */
@OptIn(ExperimentalCoroutinesApi::class)
@Suppress("LongParameterList") // What its status combines, plus the clock and IDs a resolution needs.
internal class ProfileSyncService(
    private val profiles: ProfileDatabases,
    accounts: AccountRepository,
    engine: SyncEngine,
    private val scheduler: SyncScheduler,
    private val clock: Clock,
    private val newId: () -> AwradId,
    scope: CoroutineScope,
) : SyncService {

    private val local = profiles.active.flatMapLatest { profile ->
        val dao = profile.database.syncDao()
        combine(dao.observeOutboxCount(), dao.observeMeta()) { pending, meta ->
            LocalSyncState(profile.accountId, pending, meta?.lastSyncedAt?.let(Instant::ofEpochMilli))
        }
    }

    override val status: StateFlow<SyncStatus> = combine(
        accounts.session,
        local,
        engine.state,
    ) { session, local, engine ->
        val signedIn = (session as? SignInState.SignedIn)?.account?.id
        val state = when {
            signedIn == null -> SyncState.SIGNED_OUT
            local.accountId != signedIn -> SyncState.WAITING
            else -> when (engine) {
                EngineState.IDLE -> SyncState.IDLE
                EngineState.SYNCING -> SyncState.SYNCING
                EngineState.RETRYING -> SyncState.RETRYING
                EngineState.ACCOUNT_MISMATCH -> SyncState.ACCOUNT_MISMATCH
            }
        }
        SyncStatus(state, local.lastSyncedAt, local.pending)
    }.stateIn(scope, SharingStarted.WhileSubscribed(STOP_TIMEOUT_MS), SyncStatus())

    override val conflicts: Flow<List<OpenConflict>> = profiles.active.flatMapLatest { profile ->
        profile.database.syncDao().observeConflicts().map { rows ->
            rows.map { it.toConflict() }.map {
                OpenConflict(
                    it.key,
                    it.localOp,
                )
            }
        }
    }

    override val notices: Flow<List<SyncNotice>> = profiles.active.flatMapLatest { profile ->
        profile.database.syncDao().observeNotices().map { rows ->
            rows.mapNotNull { row ->
                val type = EntityType.fromWire(row.entityType) ?: return@mapNotNull null
                val id = AwradId.parse(row.entityId) ?: return@mapNotNull null
                SyncNotice(RejectionCode.fromWire(row.code), EntityKey(type, id))
            }
        }
    }

    override fun requestSync(debounced: Boolean) {
        scheduler.request(debounced)
    }

    override suspend fun resolve(key: EntityKey, choice: ConflictChoice) {
        val orphaned = profiles.write { profile ->
            val store = RoomSyncStore(profile.database.syncDao(), now = clock::millis)
            ApplyChanges.resolve(store, key, choice, newId())
            store.orphanedAudio
        }
        orphaned?.forEach { File(it).delete() }
        requestSync(debounced = false)
    }

    override suspend fun dismissNotice(notice: SyncNotice) {
        profiles.write { profile ->
            profile.database.syncDao().deleteNotice(notice.code.wire, notice.key.type.wire, notice.key.id.value)
        }
    }

    private data class LocalSyncState(val accountId: AwradId?, val pending: Int, val lastSyncedAt: Instant?)

    private companion object {
        const val STOP_TIMEOUT_MS = 5_000L
    }
}
