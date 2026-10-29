package app.awrad.core.data.personal

import app.awrad.core.data.profile.OpenProfile
import app.awrad.core.data.profile.ProfileDatabases
import app.awrad.core.data.sync.RoomSyncStore
import app.awrad.core.data.sync.toLocal
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.personal.PersonalDocument
import app.awrad.core.domain.personal.TagError
import app.awrad.core.domain.personal.TagName
import app.awrad.core.domain.personal.TagNameResult
import app.awrad.core.domain.personal.TagOutcome
import app.awrad.core.domain.personal.TagRepository
import app.awrad.core.domain.personal.UserTag
import app.awrad.core.domain.personal.UserTagJson
import app.awrad.core.domain.sync.EntityKey
import app.awrad.core.domain.sync.EntityType
import app.awrad.core.domain.sync.LocalEdit
import app.awrad.core.domain.sync.LocalEntity
import app.awrad.core.domain.sync.Outbox
import app.awrad.core.domain.sync.SyncOp
import app.awrad.core.domain.sync.SyncService
import app.awrad.core.domain.sync.personalKeyOf
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.map
import java.time.Clock

/**
 * The active profile's tags and personal records in Room. Names are normalized and compared as the shared rules
 * say (`tag_name_normalization`); each change and its queued command are one transaction.
 */
@OptIn(ExperimentalCoroutinesApi::class)
internal class RoomTagRepository(
    private val profiles: ProfileDatabases,
    private val sync: SyncService,
    private val clock: Clock,
    private val newId: () -> AwradId,
) : TagRepository {

    override val tags: Flow<List<UserTag>> = profiles.active.flatMapLatest { profile ->
        profile.database.syncDao().observeUserTags().map { rows ->
            rows.map { UserTag(AwradId(it.id), it.name, it.normalizedName) }
        }
    }

    override val tagsByDhikr: Flow<Map<AwradId, List<AwradId>>> = profiles.active.flatMapLatest { profile ->
        profile.database.syncDao().observePersonals().map { rows ->
            rows.associate { row -> AwradId(row.dhikrId) to PersonalDocument.tagIds(row.toLocal().document) }
                .filterValues { it.isNotEmpty() }
        }
    }

    override suspend fun create(name: String): TagOutcome = saveTag(id = null, input = name)

    override suspend fun rename(id: AwradId, name: String): TagOutcome = saveTag(id = id, input = name)

    private suspend fun saveTag(id: AwradId?, input: String): TagOutcome {
        val name = when (val result = TagName.of(input)) {
            is TagNameResult.Accepted -> result.name
            is TagNameResult.Rejected -> return TagOutcome.Failed(TagError.InvalidName(result.problem))
        }
        val outcome = profiles.write { profile ->
            val store = RoomSyncStore(profile.database.syncDao(), now = clock::millis)
            val existing = store.entities(EntityType.USER_TAG).mapNotNull { UserTagJson.decode(it.key.id, it.document) }
            val error = when {
                id != null && existing.none { it.id == id } -> TagError.NotFound
                existing.any { it.normalizedName == name.normalized && it.id != id } -> TagError.NameTaken
                id == null && existing.size >= UserTag.LIMIT -> TagError.LimitReached
                else -> null
            }
            if (error != null) return@write TagOutcome.Failed(error)
            val key = EntityKey(EntityType.USER_TAG, id ?: newId())
            val document = UserTagJson.encode(name)
            store.putEntity(LocalEntity(key, store.entity(key)?.knownVersion ?: 0, document))
            enqueue(profile, store, LocalEdit(newId(), key, SyncOp.PUT, document))
            TagOutcome.Saved(UserTag(key.id, name.display, name.normalized))
        }
        if (outcome is TagOutcome.Saved) sync.requestSync()
        return outcome ?: TagOutcome.Failed(TagError.NotFound)
    }

    /**
     * Deletes the tag, queuing only the tag delete (`outbox_enqueue`): the server takes it out of every personal
     * record itself and reports them in the receipt's `cascaded`. Locally, in the same transaction, the tag leaves
     * every personal record (here) and every never-sent personal-record command (the queue rules).
     */
    override suspend fun delete(id: AwradId) {
        profiles.write { profile ->
            val store = RoomSyncStore(profile.database.syncDao(), now = clock::millis)
            store.entities(EntityType.DHIKR_PERSONAL).forEach { record ->
                val tags = PersonalDocument.tagIds(record.document)
                if (id in tags) store.putEntity(record.copy(document = PersonalDocument.of(tags - id)))
            }
            val key = EntityKey(EntityType.USER_TAG, id)
            enqueue(profile, store, LocalEdit(newId(), key, SyncOp.DELETE, null))
            store.removeEntity(key)
            store.removeConflict(key)
        }
        sync.requestSync()
    }

    override suspend fun setTags(dhikrId: AwradId, tagIds: List<AwradId>): TagError? {
        val tags = tagIds.distinct()
        if (tags.size > UserTag.PER_DHIKR) return TagError.TooManyOnDhikr
        val error = profiles.write { profile ->
            val store = RoomSyncStore(profile.database.syncDao(), now = clock::millis)
            if (tags.any { store.entity(EntityKey(EntityType.USER_TAG, it)) == null }) return@write TagError.NotFound
            val key = personalKeyOf(dhikrId)
            val existing = store.entity(key)
            val document = PersonalDocument.of(tags)
            if (existing?.document == document) return@write null
            store.putEntity(LocalEntity(key, existing?.knownVersion ?: 0, document))
            enqueue(profile, store, LocalEdit(newId(), key, SyncOp.PUT, document))
            null
        }
        if (error == null) sync.requestSync()
        return error
    }

    /** Queues [edit] when the profile belongs to an account; the anonymous profile only saves. */
    private fun enqueue(profile: OpenProfile, store: RoomSyncStore, edit: LocalEdit) {
        if (profile.queuesEdits) Outbox.enqueue(store, edit)
    }
}
