package app.awrad.core.data.sync

import app.awrad.core.data.audio.AudioUploader
import app.awrad.core.data.practice.PolicySeed
import app.awrad.core.data.profile.OpenProfile
import app.awrad.core.data.profile.ProfileDatabases
import app.awrad.core.database.NoticeEntity
import app.awrad.core.database.RegistryDao
import app.awrad.core.database.SyncMetaEntity
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.account.AccountRepository
import app.awrad.core.domain.account.SignInState
import app.awrad.core.domain.sync.ApplyChanges
import app.awrad.core.domain.sync.SyncCadence
import app.awrad.core.domain.sync.SyncNotice
import app.awrad.core.network.api.ApiFailure
import app.awrad.core.network.api.ApiResult
import app.awrad.core.network.api.SyncCommandBatch
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.io.File
import java.time.Clock
import java.time.Duration

/** How one sync run ended, which decides when the next one runs. */
internal sealed interface SyncOutcome {
    /** Everything was sent and pulled. */
    data object Done : SyncOutcome

    /** It may not sync now: signed out, or the active profile isn't the signed-in account's. */
    data object Skipped : SyncOutcome

    /** The server or network failed; retry with backoff (or after [retryAfter], when the server said). */
    data class Failed(val retryAfter: Duration?) : SyncOutcome

    /** The server said the request was for another account. Nothing more is sent until that changes. */
    data object AccountMismatch : SyncOutcome
}

/** What the engine is doing, for [SyncService.status][app.awrad.core.domain.sync.SyncService.status]. */
internal enum class EngineState { IDLE, SYNCING, RETRYING, ACCOUNT_MISMATCH }

/**
 * Sends the active profile's queue and pulls its changes (contracts/sync/v1/README.md, "Sending and pulling").
 *
 * Two safety checks keep accounts apart: it runs only while the signed-in account owns the active profile, and
 * every request names that account (`X-Awrad-Account`). Signed out, it makes no request at all. Each step's local
 * writes are bound to the profile the run started with, so a profile switch mid-run stops it instead of mixing
 * data.
 */
@Suppress("LongParameterList") // The seams a run crosses: profiles, registry, session, server, uploads, clock, IDs.
internal class SyncEngine(
    private val profiles: ProfileDatabases,
    private val registry: RegistryDao,
    private val accounts: AccountRepository,
    private val remote: SyncRemote,
    private val clock: Clock,
    /** Uploads the profile's queued recordings first, so a confirmed one's put goes out in the same run. */
    private val uploads: AudioUploader? = null,
    private val newId: () -> AwradId = { AwradId.random(clock) },
) {
    private val mutex = Mutex()
    private val mutableState = MutableStateFlow(EngineState.IDLE)
    val state: StateFlow<EngineState> = mutableState.asStateFlow()

    /** The profile and account a `409 account_mismatch` came for; skipped until either changes. */
    private var mismatch: Pair<AwradId, AwradId>? = null

    /** One run: send every queued command in batches, then pull every page. One run at a time. */
    suspend fun syncOnce(): SyncOutcome = mutex.withLock {
        val account = (accounts.session.first() as? SignInState.SignedIn)?.account
            ?: return@withLock SyncOutcome.Skipped
        val profile = profiles.current()
        if (profile.accountId != account.id || profile.accountDeleted) return@withLock SyncOutcome.Skipped
        if (mismatch == profile.profileId to account.id) return@withLock SyncOutcome.AccountMismatch
        mutableState.value = EngineState.SYNCING
        val outcome = run(profile.profileId, account.id)
        if (outcome == SyncOutcome.AccountMismatch) mismatch = profile.profileId to account.id
        mutableState.value = when (outcome) {
            SyncOutcome.Done, SyncOutcome.Skipped -> EngineState.IDLE
            is SyncOutcome.Failed -> EngineState.RETRYING
            SyncOutcome.AccountMismatch -> EngineState.ACCOUNT_MISMATCH
        }
        outcome
    }

    /**
     * Uploads queued recordings, then sends the queue and pulls. A recording left to retry doesn't hold back the
     * queue; the run still backs off for it. When the receipts queued a recording again (an audio rejection), one
     * more round uploads it and sends the put naming it.
     */
    private suspend fun run(profileId: AwradId, accountId: AwradId): SyncOutcome {
        var rounds = 0
        var outcome: SyncOutcome
        do {
            val uploaded = uploads?.uploadAll(profileId, accountId) ?: SyncOutcome.Done
            if (uploaded == SyncOutcome.Skipped || uploaded == SyncOutcome.AccountMismatch) return uploaded
            val exchanged = exchange(profileId, accountId)
            outcome = if (exchanged == SyncOutcome.Done && uploaded is SyncOutcome.Failed) uploaded else exchanged
            rounds++
        } while (outcome == SyncOutcome.Done && rounds < MAX_ROUNDS && uploads?.hasQueued(profileId) == true)
        return outcome
    }

    /**
     * Sends the queue, then pulls every page, then settles a first sign-in's practice policy (sending the create it
     * may queue), then records the sync.
     */
    private suspend fun exchange(profileId: AwradId, accountId: AwradId): SyncOutcome =
        send(profileId, accountId) ?: pull(profileId, accountId) ?: seedPolicy(profileId, accountId) ?: run {
            profiles.write(profileId) { open ->
                val dao = open.database.syncDao()
                dao.upsertMeta(SyncMetaEntity(after = dao.meta()?.after ?: 0, lastSyncedAt = clock.millis()))
            }
            SyncOutcome.Done
        }

    /** Sends the queue in batches of up to 100, applying each batch's receipts. Null when it all went. */
    @Suppress("ReturnCount") // Each step can end the run: a profile switch, a failure, an empty queue.
    private suspend fun send(profileId: AwradId, accountId: AwradId): SyncOutcome? {
        val sentThisRun = mutableSetOf<AwradId>()
        while (true) {
            val commands = profiles.write(profileId) { open ->
                val dao = open.database.syncDao()
                val commands = dao.outbox().take(SyncCadence.BATCH_SIZE)
                // Marked before the request: a sent command is never rewritten, even if no receipt comes back.
                if (commands.isNotEmpty()) dao.markSent(commands.map { it.commandId })
                commands.map { it.toCommand() }
            } ?: return SyncOutcome.Skipped
            // Stop when the queue is empty, or holds only commands already sent this run (a receipt didn't come
            // back). Commands the receipts queued (an audio rejection's put) go in the next round.
            if (commands.all { it.commandId in sentThisRun }) return null
            sentThisRun += commands.map { it.commandId }
            val result = remote.postCommands(accountId, SyncCommandBatch(commands.map { it.toWire() }))
            val receipts = when (result) {
                is ApiResult.Success -> result.value.receipts.mapNotNull { it.toDomain() }
                is ApiResult.Failure -> return outcomeOf(result.failure)
            }
            val orphaned = profiles.write(profileId) { open -> applyReceipts(open, receipts) }
                ?: return SyncOutcome.Skipped
            deleteFiles(orphaned)
        }
    }

    private fun applyReceipts(open: OpenProfile, receipts: List<app.awrad.core.domain.sync.Receipt>): List<String> {
        val dao = open.database.syncDao()
        val store = RoomSyncStore(dao, now = clock::millis)
        ApplyChanges.applyReceipts(store, receipts, newId).forEach { notice -> dao.insertNotice(notice.toEntity()) }
        return store.orphanedAudio
    }

    /** Pulls pages from the stored `after`, each applied with its `next_after` in one transaction. */
    @Suppress("ReturnCount") // Each page can end the run: a profile switch, a failure, the last page.
    private suspend fun pull(profileId: AwradId, accountId: AwradId): SyncOutcome? {
        while (true) {
            val after = profiles.write(profileId) { open -> open.database.syncDao().meta()?.after ?: 0L }
                ?: return SyncOutcome.Skipped
            val page = when (val result = remote.listChanges(accountId, after, SyncCadence.PAGE_SIZE)) {
                is ApiResult.Success -> result.value.toDomain()
                is ApiResult.Failure -> return outcomeOf(result.failure)
            }
            val orphaned = profiles.write(profileId) { open ->
                val store = RoomSyncStore(open.database.syncDao(), now = clock::millis)
                ApplyChanges.applyPage(store, page)
                store.orphanedAudio
            } ?: return SyncOutcome.Skipped
            deleteFiles(orphaned)
            registry.setAfter(profileId.value, page.nextAfter)
            if (!page.hasMore) return null
        }
    }

    /**
     * After the first complete pull of a profile a first sign-in made, whose policy wins is known: the account's, if
     * the feed had one, else this phone's chosen one, queued and sent now ([PolicySeed]). Null when nothing's left.
     */
    private suspend fun seedPolicy(profileId: AwradId, accountId: AwradId): SyncOutcome? {
        val queued = profiles.write(profileId) { open ->
            PolicySeed.settle(open.database.syncDao(), accountId, clock::millis, newId)
        } ?: return SyncOutcome.Skipped
        return if (queued) send(profileId, accountId) else null
    }

    private fun outcomeOf(failure: ApiFailure): SyncOutcome = when (failure) {
        is ApiFailure.ProblemResponse -> when {
            failure.problem.code == ACCOUNT_MISMATCH -> SyncOutcome.AccountMismatch
            // The session ended: the device is signed out now, and nothing more is sent.
            failure.status == UNAUTHORIZED -> SyncOutcome.Skipped
            else -> SyncOutcome.Failed(failure.retryAfterSeconds?.let(Duration::ofSeconds))
        }
        ApiFailure.NotSignedIn -> SyncOutcome.Skipped
        ApiFailure.NoConnection, is ApiFailure.UnexpectedResponse -> SyncOutcome.Failed(null)
    }

    private fun deleteFiles(paths: List<String>) {
        paths.forEach { File(it).delete() }
    }

    private companion object {
        /** Upload-and-exchange rounds in one run: the first, and one for recordings the receipts queued again. */
        const val MAX_ROUNDS = 2
        const val ACCOUNT_MISMATCH = "account_mismatch"
        const val UNAUTHORIZED = 401
    }
}

internal fun SyncNotice.toEntity() = NoticeEntity(code = code.wire, entityType = key.type.wire, entityId = key.id.value)
