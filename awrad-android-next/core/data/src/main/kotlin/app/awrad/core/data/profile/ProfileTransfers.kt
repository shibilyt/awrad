package app.awrad.core.data.profile

import app.awrad.core.data.practice.PolicySeed
import app.awrad.core.data.sync.RoomSyncStore
import app.awrad.core.database.CustomDhikrEntity
import app.awrad.core.database.PracticePolicyEntity
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.personal.CustomAudioJson
import app.awrad.core.domain.personal.PersonalDocument
import app.awrad.core.domain.personal.UserTagJson
import app.awrad.core.domain.sync.EntityKey
import app.awrad.core.domain.sync.EntityType
import app.awrad.core.domain.sync.LocalEdit
import app.awrad.core.domain.sync.LocalEntity
import app.awrad.core.domain.sync.Outbox
import app.awrad.core.domain.sync.PersonalRecord
import app.awrad.core.domain.sync.ProfileData
import app.awrad.core.domain.sync.ProfileMerge
import app.awrad.core.domain.sync.SyncOp
import kotlinx.serialization.json.JsonObject
import java.io.File
import java.time.Clock

/** Moving data between profiles, and what each profile holds (for the profile rules). */
internal class ProfileTransfers(
    private val databases: ProfileDatabases,
    private val clock: Clock,
    private val newId: () -> AwradId,
) {
    /** Whether [profileId] holds any custom dhikr, tag or personal record. */
    suspend fun hasData(profileId: AwradId): Boolean =
        databases.writeTo(profileId) { it.database.syncDao().hasData() }

    /** Whether [profileId]'s queue holds commands not yet acknowledged. */
    suspend fun hasUnsent(profileId: AwradId): Boolean =
        databases.writeTo(profileId) { it.database.syncDao().outboxCount() > 0 }

    /**
     * "Add to my account": queues every entity of [profileId] as a put, tags first, then custom dhikrs, then the
     * personal records that name them, so the server meets each before it's referenced; and every recording kept
     * only on this phone for upload, which queues its dhikr's put again once it's confirmed.
     */
    suspend fun queueAll(profileId: AwradId) {
        databases.writeTo(profileId) { profile ->
            val store = RoomSyncStore(profile.database.syncDao(), now = clock::millis)
            ORDER.forEach { type ->
                store.entities(type).forEach { entity ->
                    Outbox.enqueue(store, LocalEdit(newId(), entity.key, SyncOp.PUT, entity.document))
                    if (type == EntityType.CUSTOM_DHIKR) queueLocalRecording(store, entity.key.id, entity.document)
                }
            }
        }
    }

    /** Queues the upload of [dhikrId]'s recording if it's only on this phone and its file is here. */
    private fun queueLocalRecording(store: RoomSyncStore, dhikrId: AwradId, document: JsonObject) {
        if (CustomAudioJson.isLocalOnly(document["audio"]) && store.hasAudioFile(dhikrId)) store.queueUpload(dhikrId)
    }

    /** [profileId]'s practice policy row, or null while it's untouched. */
    suspend fun practicePolicyOf(profileId: AwradId): PracticePolicyEntity? =
        databases.writeTo(profileId) { it.database.syncDao().practicePolicy() }

    /**
     * A first sign-in from the anonymous profile made [into] the account's (the same profile when adopted, a fresh
     * one on Erase): [into] takes the anonymous practice policy ([anonymous], read before the switch) and waits for
     * the account's ([PolicySeed]). Settings alone never count as data, so this runs whatever the user answered.
     */
    suspend fun startPolicySeed(into: AwradId, anonymous: PracticePolicyEntity?, accountId: AwradId) {
        databases.writeTo(into) { PolicySeed.start(it.database.syncDao(), anonymous, accountId) }
    }

    /** Keep on a deleted account's profile: its unsent commands can never be sent, so they're dropped. */
    suspend fun dropQueue(profileId: AwradId) {
        databases.writeTo(profileId) { profile ->
            RoomSyncStore(profile.database.syncDao(), now = clock::millis).replaceOutbox(emptyList())
        }
    }

    /**
     * Adds the anonymous profile [from]'s data to the account's existing profile [into] and queues it there
     * ([ProfileMerge]): same-name tags fold onto [into]'s, a dhikr tagged in both gets the union of their tags,
     * and the new tags, every custom dhikr, then the new or changed personal records are queued as puts, in that
     * order. Recordings are copied into [into]'s files and queued for upload.
     */
    suspend fun mergeAnonymous(from: AwradId, into: AwradId) {
        val source = databases.writeTo(from) { profile ->
            val dao = profile.database.syncDao()
            AnonymousData(RoomSyncStore(dao, now = clock::millis).profileData(), dao.customDhikrs())
        }
        databases.writeTo(into) { profile ->
            val dao = profile.database.syncDao()
            val store = RoomSyncStore(dao, now = clock::millis)
            val merged = ProfileMerge.merge(anonymous = source.data, account = store.profileData())
            fun put(key: EntityKey, document: JsonObject) {
                store.putEntity(LocalEntity(key, store.entity(key)?.knownVersion ?: 0, document))
                Outbox.enqueue(store, LocalEdit(newId(), key, SyncOp.PUT, document))
            }
            val tags = merged.tags.associateBy { it.id }
            val records = merged.personalRecords.associateBy { it.dhikrId }
            merged.queued.filter { it.type == EntityType.USER_TAG }.forEach { key ->
                put(key, UserTagJson.encode(tags.getValue(key.id)))
            }
            source.dhikrs.forEach { dhikr ->
                val audio = dhikr.audioFile?.let { copyInto(File(it), profile.filesDir) }
                dao.upsertCustomDhikr(dhikr.copy(knownVersion = 0, audioFile = audio))
                val key = EntityKey(EntityType.CUSTOM_DHIKR, AwradId(dhikr.id))
                val document = checkNotNull(store.entity(key)).document
                Outbox.enqueue(store, LocalEdit(newId(), key, SyncOp.PUT, document))
                queueLocalRecording(store, key.id, document)
            }
            merged.queued.filter { it.type == EntityType.DHIKR_PERSONAL }.forEach { key ->
                put(key, PersonalDocument.of(records.getValue(key.id).tagIds))
            }
        }
    }

    private fun copyInto(file: File, profileDir: File): String? {
        if (!file.isFile) return null
        val target = File(File(profileDir, "audio").apply { mkdirs() }, file.name)
        file.copyTo(target, overwrite = true)
        return target.path
    }

    /** The profile's tags and personal records, as the merge rule reads them. */
    private fun RoomSyncStore.profileData() = ProfileData(
        tags = entities(EntityType.USER_TAG).mapNotNull { UserTagJson.decode(it.key.id, it.document) },
        personalRecords = entities(EntityType.DHIKR_PERSONAL).map {
            PersonalRecord(it.key.id, PersonalDocument.tagIds(it.document))
        },
    )

    private class AnonymousData(val data: ProfileData, val dhikrs: List<CustomDhikrEntity>)

    private companion object {
        val ORDER = listOf(EntityType.USER_TAG, EntityType.CUSTOM_DHIKR, EntityType.DHIKR_PERSONAL)
    }
}
