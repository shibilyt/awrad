package app.awrad.core.data.personal

import app.awrad.core.data.profile.OpenProfile
import app.awrad.core.data.profile.ProfileDatabases
import app.awrad.core.data.sync.RoomSyncStore
import app.awrad.core.data.sync.parseDocument
import app.awrad.core.database.CustomDhikrEntity
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.personal.AudioImport
import app.awrad.core.domain.personal.CustomDhikr
import app.awrad.core.domain.personal.CustomDhikrError
import app.awrad.core.domain.personal.CustomDhikrJson
import app.awrad.core.domain.personal.CustomDhikrRepository
import app.awrad.core.domain.personal.CustomDhikrValidity
import app.awrad.core.domain.sync.EntityKey
import app.awrad.core.domain.sync.EntityType
import app.awrad.core.domain.sync.LocalEdit
import app.awrad.core.domain.sync.Outbox
import app.awrad.core.domain.sync.SyncOp
import app.awrad.core.domain.sync.SyncService
import app.awrad.core.domain.sync.personalKeyOf
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonObject
import java.io.File
import java.time.Clock

/**
 * The active profile's custom dhikrs in Room. A save writes the dhikr and queues its command in one transaction
 * (only a profile that belongs to an account queues; ProfileSwitch.queuesEdits), then asks for a sync, which
 * does nothing while signed out.
 */
@OptIn(ExperimentalCoroutinesApi::class)
internal class RoomCustomDhikrRepository(
    private val profiles: ProfileDatabases,
    private val audio: AudioFiles,
    private val sync: SyncService,
    private val clock: Clock,
    private val newId: () -> AwradId,
    private val io: CoroutineDispatcher,
) : CustomDhikrRepository {

    override val dhikrs: Flow<List<CustomDhikr>> = profiles.active.flatMapLatest { profile ->
        profile.database.syncDao().observeCustomDhikrs().map { rows -> rows.mapNotNull { it.toDomain() } }
    }

    override fun dhikr(id: AwradId): Flow<CustomDhikr?> =
        dhikrs.map { list -> list.firstOrNull { it.id == id } }.distinctUntilChanged()

    override suspend fun save(dhikr: CustomDhikr): CustomDhikrError? {
        val document = CustomDhikrJson.encode(dhikr)
        val errors = CustomDhikrValidity.errors(document)
        val outcome = if (errors.isEmpty()) {
            profiles.write { profile -> write(profile, dhikr, document) }
                ?: SaveOutcome(CustomDhikrError.NotFound, null)
        } else {
            SaveOutcome(CustomDhikrError.Invalid(errors), null)
        }
        outcome.unusedAudio?.let { deleteFile(it) }
        if (outcome.error == null) sync.requestSync()
        return outcome.error
    }

    /** Writes [dhikr] and queues its put, in the profile's transaction; a replaced recording is to be deleted. */
    private fun write(profile: OpenProfile, dhikr: CustomDhikr, document: JsonObject): SaveOutcome {
        val dao = profile.database.syncDao()
        val existing = dao.customDhikr(dhikr.id.value)
        if (existing == null && dao.customDhikrCount() >= CustomDhikr.LIMIT) {
            return SaveOutcome(CustomDhikrError.LimitReached, null)
        }
        // A recording made on another device has no local file: keep whatever this phone has.
        val audioFile = dhikr.audio?.let { it.localUri?.let(audio::pathOf) ?: existing?.audioFile }
        dao.upsertCustomDhikr(
            CustomDhikrEntity(
                id = dhikr.id.value,
                knownVersion = existing?.knownVersion ?: 0,
                document = document.toString(),
                audioFile = audioFile,
                createdAt = existing?.createdAt ?: clock.millis(),
            ),
        )
        if (profile.accountId != null) {
            val key = EntityKey(EntityType.CUSTOM_DHIKR, dhikr.id)
            Outbox.enqueue(RoomSyncStore(dao, clock::millis), LocalEdit(newId(), key, SyncOp.PUT, document))
        }
        return SaveOutcome(null, existing?.audioFile?.takeIf { it != audioFile })
    }

    override suspend fun delete(id: AwradId) {
        val key = EntityKey(EntityType.CUSTOM_DHIKR, id)
        val personal = personalKeyOf(id)
        val orphaned = profiles.write { profile ->
            val store = RoomSyncStore(profile.database.syncDao(), clock::millis)
            // The queue rules first, on the whole queue: they drop a never-sent create and its tags' commands.
            if (profile.accountId != null) Outbox.enqueue(store, LocalEdit(newId(), key, SyncOp.DELETE, null))
            // The server deletes the personal record itself; locally it goes with the dhikr.
            listOf(key, personal).forEach { gone ->
                store.removeEntity(gone)
                store.removeConflict(gone)
            }
            store.orphanedAudio
        }
        orphaned?.forEach { deleteFile(it) }
        sync.requestSync()
    }

    override suspend fun importAudio(sourceUri: String): AudioImport {
        val profile = profiles.current()
        return withContext(io) { audio.import(sourceUri, profile.filesDir, newId().value) }
    }

    override suspend fun discardAudio(localUri: String) {
        audio.pathOf(localUri)?.let { deleteFile(it) }
    }

    private suspend fun deleteFile(path: String) {
        withContext(io) { File(path).delete() }
    }

    private fun CustomDhikrEntity.toDomain(): CustomDhikr? =
        CustomDhikrJson.decode(AwradId(id), parseDocument(document), audioFile?.let(audio::uriOf))

    private data class SaveOutcome(val error: CustomDhikrError?, val unusedAudio: String?)
}
