package app.awrad.core.domain.sync

import app.awrad.core.domain.AwradId
import kotlinx.serialization.json.JsonObject

/*
 * The change queue's shapes on a phone (contracts/sync/v1, root ADR-2026-10-28 "The change queue"). Documents stay
 * JSON objects here: the queue moves whole documents and never reads inside them, except where a rule says so
 * (a `dhikr_personal`'s tag IDs).
 */

/** What kind of entity a synced document is. [wire] is its `entity_type`. */
public enum class EntityType(public val wire: String) {
    CUSTOM_DHIKR("custom_dhikr"),
    USER_TAG("user_tag"),
    DHIKR_PERSONAL("dhikr_personal"),

    /** The account practice policy (slice 3d): one per account, its ID the account's, never deleted. */
    PRACTICE_POLICY("practice_policy"),

    /** A goal (slice 4): the whole goal document ([app.awrad.core.domain.goal.GoalJson]), with a new UUIDv7. */
    GOAL("goal"),

    /** The user's order of My Goals (slice 4): one per account, its ID the account's, never deleted. */
    GOAL_ORDER("goal_order"),
    ;

    /** One per account, merged by the phone on a conflict against the [LocalEntity.baseDocument] it keeps. */
    public val mergesConflicts: Boolean get() = this == PRACTICE_POLICY || this == GOAL_ORDER

    public companion object {
        public fun fromWire(wire: String): EntityType? = entries.firstOrNull { it.wire == wire }
    }
}

/** One entity: its type and ID. Sorted by `entity_type`, then `entity_id`, as the fixtures list them. */
public data class EntityKey(val type: EntityType, val id: AwradId) : Comparable<EntityKey> {
    override fun compareTo(other: EntityKey): Int =
        compareValuesBy(this, other, { it.type.wire }, { it.id.value })

    override fun toString(): String = "${type.wire}/${id.value}"
}

/** A command's operation: `put` creates or replaces the whole document, `delete` makes a final tombstone. */
public enum class SyncOp(public val wire: String) {
    PUT("put"),
    DELETE("delete"),
    ;

    public companion object {
        public fun fromWire(wire: String): SyncOp? = entries.firstOrNull { it.wire == wire }
    }
}

/** An entity's state on the server. Deletes are final. */
public enum class EntityState(public val wire: String) {
    ACTIVE("active"),
    DELETED("deleted"),
    ;

    public companion object {
        public fun fromWire(wire: String): EntityState? = entries.firstOrNull { it.wire == wire }
    }
}

/**
 * An entity present on the phone: its [document] and the last server version this phone has seen of it
 * ([knownVersion], 0 while the server hasn't confirmed it). Deleted entities aren't kept.
 *
 * A [practice policy][EntityType.PRACTICE_POLICY] or [goal order][EntityType.GOAL_ORDER] also keeps [baseDocument]:
 * the server copy its document was edited from (the default policy, or an empty order, when the phone knows none),
 * which a conflict merges against. It's null for every other entity.
 */
public data class LocalEntity(
    val key: EntityKey,
    val knownVersion: Long,
    val document: JsonObject,
    val baseDocument: JsonObject? = null,
)

/**
 * One queued command, oldest first in the outbox. [sent] is true once it has been in a request, whether or not
 * its receipt came back; a sent command is never rewritten. [document] is null for a delete.
 */
public data class OutboxCommand(
    val commandId: AwradId,
    val key: EntityKey,
    val op: SyncOp,
    val baseVersion: Long,
    val document: JsonObject?,
    val sent: Boolean,
)

/** The server's copy of an entity, as a receipt or a conflict carries it (`$defs/current`). */
public data class ServerCopy(val version: Long, val state: EntityState, val document: JsonObject?)

/**
 * An open conflict ("Changed on another device"): the server had moved on when this phone's edit arrived.
 * [localOp] is [SyncOp.PUT] when the entity exists locally, else [SyncOp.DELETE]; [server] is the copy the user
 * can take instead.
 */
public data class SyncConflict(val key: EntityKey, val localOp: SyncOp, val server: ServerCopy)

/** One entry of the changes feed: an entity's latest state. [document] is null for a delete. */
public data class Change(
    val key: EntityKey,
    val state: EntityState,
    val version: Long,
    val revision: Long,
    val document: JsonObject?,
)

/** One page of the changes feed. Store [nextAfter] with the page, in one transaction. */
public data class ChangesPage(
    val changes: List<Change>,
    val nextAfter: Long,
    val hasMore: Boolean,
    val headRevision: Long,
)

/** One edit saved on the phone, before the queue rules decide how it's queued ([Outbox.enqueue]). */
public data class LocalEdit(
    val commandId: AwradId,
    val key: EntityKey,
    val op: SyncOp,
    val document: JsonObject?,
)
