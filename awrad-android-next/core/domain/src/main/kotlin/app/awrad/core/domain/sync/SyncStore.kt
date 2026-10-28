package app.awrad.core.domain.sync

import app.awrad.core.domain.AwradId

/**
 * One profile's synced state, seen inside one local transaction: the entities with their known versions, the
 * outbox, the open conflicts and the changes-feed position. The queue rules ([Outbox], [ApplyChanges]) read and
 * write it; `:core:data` backs it with the profile's Room database, the fixture runners with memory.
 *
 * Calls are blocking: an implementation runs them inside its own transaction.
 */
public interface SyncStore {
    /** The changes-feed position: the last `next_after` applied. */
    public var after: Long

    /** The entity with [key], or null when it isn't on the phone. */
    public fun entity(key: EntityKey): LocalEntity?

    /** Every entity of [type] on the phone. */
    public fun entities(type: EntityType): List<LocalEntity>

    /** Adds [entity], or replaces the document and known version of the one with its key. */
    public fun putEntity(entity: LocalEntity)

    /** Removes the entity with [key], if it's there. Nothing else changes (see [ApplyChanges]'s cascades). */
    public fun removeEntity(key: EntityKey)

    /** The whole queue, oldest first. */
    public fun outbox(): List<OutboxCommand>

    /**
     * Makes the queue [commands]. The queue rules only ever replace a command in place, remove commands or add
     * new ones at the end, so commands keep their relative order.
     */
    public fun replaceOutbox(commands: List<OutboxCommand>)

    /** The open conflict on [key], or null. */
    public fun conflict(key: EntityKey): SyncConflict?

    public fun putConflict(conflict: SyncConflict)

    public fun removeConflict(key: EntityKey)
}

/** The queued commands for [key], oldest first. */
public fun SyncStore.commandsFor(key: EntityKey): List<OutboxCommand> = outbox().filter { it.key == key }

/** The [dhikr_personal][EntityType.DHIKR_PERSONAL] key of the dhikr with [dhikrId]. */
public fun personalKeyOf(dhikrId: AwradId): EntityKey = EntityKey(EntityType.DHIKR_PERSONAL, dhikrId)
