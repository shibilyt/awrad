package app.awrad.core.data.practice

import app.awrad.core.data.profile.ProfileDatabases
import app.awrad.core.data.sync.RoomSyncStore
import app.awrad.core.data.sync.parseDocument
import app.awrad.core.database.PracticePolicyEntity
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.practice.PracticePolicy
import app.awrad.core.domain.practice.PracticePolicyJson
import app.awrad.core.domain.practice.PracticeSettingsRepository
import app.awrad.core.domain.sync.EntityKey
import app.awrad.core.domain.sync.EntityType
import app.awrad.core.domain.sync.LocalEdit
import app.awrad.core.domain.sync.Outbox
import app.awrad.core.domain.sync.SyncOp
import app.awrad.core.domain.sync.SyncService
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.map
import java.time.Clock

/**
 * The active profile's practice policy in its Room database (`practice_policy`, one row). Every change marks the
 * policy chosen. In a profile that belongs to an account, the change is the account's `practice_policy` entity and
 * is queued with it, in one transaction, as any edit is (signed out too; it's sent once signed in again); while the
 * first sign-in is still settling whose policy wins, it's only kept locally ([PolicySeed]).
 */
@OptIn(ExperimentalCoroutinesApi::class)
internal class RoomPracticeSettingsRepository(
    private val profiles: ProfileDatabases,
    private val sync: SyncService,
    private val clock: Clock,
    private val newId: () -> AwradId,
) : PracticeSettingsRepository {

    override val policy: Flow<PracticePolicy> = profiles.active.flatMapLatest { profile ->
        profile.database.syncDao().observePracticePolicy().map { it.policy() }
    }.distinctUntilChanged()

    override suspend fun update(change: (PracticePolicy) -> PracticePolicy) {
        val queued = profiles.write { profile ->
            val dao = profile.database.syncDao()
            val row = dao.practicePolicy()
            val current = row.policy()
            val updated = change(current)
            if (updated == current) return@write false
            val document = PracticePolicyJson.encode(updated)
            val account = profile.accountId?.takeIf { profile.queuesEdits }
            val queues = account != null && row?.seedPending != true
            val entityId = row?.entityId ?: account?.value?.takeIf { queues }
            dao.upsertPracticePolicy(
                PracticePolicyEntity(
                    entityId = entityId,
                    knownVersion = row?.knownVersion ?: 0,
                    document = document.toString(),
                    baseDocument = row?.baseDocument,
                    chosen = true,
                    seedPending = row?.seedPending ?: false,
                ),
            )
            if (queues && entityId != null) {
                val store = RoomSyncStore(dao, now = clock::millis)
                val key = EntityKey(EntityType.PRACTICE_POLICY, AwradId(entityId))
                Outbox.enqueue(store, LocalEdit(newId(), key, SyncOp.PUT, document))
            }
            queues
        }
        if (queued == true) sync.requestSync()
    }
}

/** The row's policy, or the default when there's no row (or, defensively, one this app can't read). */
internal fun PracticePolicyEntity?.policy(): PracticePolicy =
    this?.let { PracticePolicyJson.decode(parseDocument(it.document)) } ?: PracticePolicy.DEFAULT
