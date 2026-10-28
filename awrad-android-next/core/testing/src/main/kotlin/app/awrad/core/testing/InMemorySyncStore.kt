package app.awrad.core.testing

import app.awrad.core.domain.sync.EntityKey
import app.awrad.core.domain.sync.EntityType
import app.awrad.core.domain.sync.LocalEntity
import app.awrad.core.domain.sync.OutboxCommand
import app.awrad.core.domain.sync.SyncConflict
import app.awrad.core.domain.sync.SyncStore

/** A [SyncStore] in memory, for the fixture runners and fakes. Entities and conflicts list in key order. */
public class InMemorySyncStore(
    override var after: Long = 0,
    entities: List<LocalEntity> = emptyList(),
    outbox: List<OutboxCommand> = emptyList(),
    conflicts: List<SyncConflict> = emptyList(),
) : SyncStore {

    private val entities = sortedMapOf<EntityKey, LocalEntity>().apply { entities.forEach { put(it.key, it) } }
    private var queue: List<OutboxCommand> = outbox
    private val conflicts = sortedMapOf<EntityKey, SyncConflict>().apply { conflicts.forEach { put(it.key, it) } }

    /** Every entity, sorted by type then ID. */
    public val allEntities: List<LocalEntity> get() = entities.values.toList()

    /** Every open conflict, sorted by type then ID. */
    public val allConflicts: List<SyncConflict> get() = conflicts.values.toList()

    override fun entity(key: EntityKey): LocalEntity? = entities[key]

    override fun entities(type: EntityType): List<LocalEntity> = entities.values.filter { it.key.type == type }

    override fun putEntity(entity: LocalEntity) {
        entities[entity.key] = entity
    }

    override fun removeEntity(key: EntityKey) {
        entities.remove(key)
    }

    override fun outbox(): List<OutboxCommand> = queue

    override fun replaceOutbox(commands: List<OutboxCommand>) {
        queue = commands.toList()
    }

    override fun conflict(key: EntityKey): SyncConflict? = conflicts[key]

    override fun putConflict(conflict: SyncConflict) {
        conflicts[conflict.key] = conflict
    }

    override fun removeConflict(key: EntityKey) {
        conflicts.remove(key)
    }
}
