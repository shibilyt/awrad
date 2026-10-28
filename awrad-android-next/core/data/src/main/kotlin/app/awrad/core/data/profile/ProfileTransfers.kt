package app.awrad.core.data.profile

import app.awrad.core.data.sync.RoomSyncStore
import app.awrad.core.database.CustomDhikrEntity
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.personal.PersonalDocument
import app.awrad.core.domain.personal.UserTag
import app.awrad.core.domain.personal.UserTagJson
import app.awrad.core.domain.sync.EntityKey
import app.awrad.core.domain.sync.EntityType
import app.awrad.core.domain.sync.LocalEdit
import app.awrad.core.domain.sync.LocalEntity
import app.awrad.core.domain.sync.Outbox
import app.awrad.core.domain.sync.SyncOp
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
     * personal records that name them, so the server meets each before it's referenced.
     */
    suspend fun queueAll(profileId: AwradId) {
        databases.writeTo(profileId) { profile ->
            val store = RoomSyncStore(profile.database.syncDao(), clock::millis)
            ORDER.forEach { type ->
                store.entities(type).forEach { entity ->
                    Outbox.enqueue(store, LocalEdit(newId(), entity.key, SyncOp.PUT, entity.document))
                }
            }
        }
    }

    /**
     * Adds the anonymous profile [from]'s data to the account's existing profile [into] and queues it there. A tag
     * whose name [into] already has becomes that tag; a dhikr tagged in both keeps both sets of tags (up to 20).
     * Recordings are copied into [into]'s files.
     */
    suspend fun mergeAnonymous(from: AwradId, into: AwradId) {
        val source = databases.writeTo(from) { profile ->
            val dao = profile.database.syncDao()
            val store = RoomSyncStore(dao, clock::millis)
            AnonymousData(
                tags = store.entities(EntityType.USER_TAG).mapNotNull { UserTagJson.decode(it.key.id, it.document) },
                dhikrs = dao.customDhikrs(),
                personals = store.entities(EntityType.DHIKR_PERSONAL),
            )
        }
        databases.writeTo(into) { profile ->
            val dao = profile.database.syncDao()
            val store = RoomSyncStore(dao, clock::millis)
            val existingTags = store.entities(
                EntityType.USER_TAG,
            ).mapNotNull { UserTagJson.decode(it.key.id, it.document) }
            val tagIds = source.tags.associate { tag ->
                val same = existingTags.firstOrNull { it.normalizedName == tag.normalizedName }
                if (same == null) {
                    val key = EntityKey(EntityType.USER_TAG, tag.id)
                    val document = UserTagJson.encode(tag)
                    store.putEntity(LocalEntity(key, 0, document))
                    Outbox.enqueue(store, LocalEdit(newId(), key, SyncOp.PUT, document))
                }
                tag.id to (same?.id ?: tag.id)
            }
            source.dhikrs.forEach { dhikr ->
                val audio = dhikr.audioFile?.let { copyInto(File(it), profile.filesDir) }
                dao.upsertCustomDhikr(dhikr.copy(knownVersion = 0, audioFile = audio))
                val key = EntityKey(EntityType.CUSTOM_DHIKR, AwradId(dhikr.id))
                Outbox.enqueue(store, LocalEdit(newId(), key, SyncOp.PUT, store.entity(key)!!.document))
            }
            source.personals.forEach { record ->
                val tags = PersonalDocument.tagIds(record.document).mapNotNull { tagIds[it] }
                val existing = store.entity(record.key)
                val merged = (existing?.let { PersonalDocument.tagIds(it.document) }.orEmpty() + tags)
                    .distinct()
                    .take(UserTag.PER_DHIKR)
                val document = PersonalDocument.of(merged)
                store.putEntity(LocalEntity(record.key, existing?.knownVersion ?: 0, document))
                Outbox.enqueue(store, LocalEdit(newId(), record.key, SyncOp.PUT, document))
            }
        }
    }

    private fun copyInto(file: File, profileDir: File): String? {
        if (!file.isFile) return null
        val target = File(File(profileDir, "audio").apply { mkdirs() }, file.name)
        file.copyTo(target, overwrite = true)
        return target.path
    }

    private class AnonymousData(
        val tags: List<UserTag>,
        val dhikrs: List<CustomDhikrEntity>,
        val personals: List<LocalEntity>,
    )

    private companion object {
        val ORDER = listOf(EntityType.USER_TAG, EntityType.CUSTOM_DHIKR, EntityType.DHIKR_PERSONAL)
    }
}
