package app.awrad.core.domain.sync

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.personal.PersonalDocument

/** The user's answer to a conflict ("Changed on another device"). */
public enum class ConflictChoice(public val wire: String) {
    /** Re-queue the local version (or delete) on the server's version. */
    KEEP_MINE("keep_mine"),

    /** Take the server's copy. */
    USE_THEIRS("use_theirs"),
}

/**
 * How a phone applies what comes back from the server (fixture `apply_changes`; contracts/sync/v1/README.md,
 * "Sending and pulling"): a changes page, the receipts for sent commands, or the user resolving a conflict. Each
 * call runs inside one local transaction of the [SyncStore].
 *
 * Removing an entity cascades the way the server does: a custom dhikr takes its `dhikr_personal` with it, and a
 * tag leaves every local `dhikr_personal` document and unsent command.
 */
public object ApplyChanges {

    /**
     * Applies one changes page, then moves `after` to its `next_after`:
     * - a delete cleans up as a `gone` receipt does, even with queued commands or an open conflict: the entity
     *   goes with its unsent commands (sent ones wait for their receipts) and its conflict, cascading locally; a
     *   delete of something the phone doesn't have is ignored;
     * - any other change to an entity with a queued command or an open conflict only updates the known version
     *   (and the conflict's server copy); the local edit stays and is settled when it's sent;
     * - otherwise an active change is stored unless it's older than the known version.
     */
    public fun applyPage(store: SyncStore, page: ChangesPage) {
        for (change in page.changes) {
            val key = change.key
            val local = store.entity(key)
            val conflict = store.conflict(key)
            val pending = store.outbox().any { it.key == key }
            when {
                change.state == EntityState.DELETED -> {
                    if (local != null || pending || conflict != null) remove(store, key)
                }
                pending || conflict != null -> recordVersion(store, change, local, conflict)
                else -> {
                    val document = checkNotNull(change.document) { "An active change of $key has no document" }
                    if (local == null || change.version >= local.knownVersion) {
                        store.putEntity(LocalEntity(key, change.version, document))
                    }
                }
            }
        }
        store.after = page.nextAfter
    }

    /** A change to an entity with a local edit in flight: only the known version (and conflict copy) move on. */
    private fun recordVersion(store: SyncStore, change: Change, local: LocalEntity?, conflict: SyncConflict?) {
        if (local != null && change.version > local.knownVersion) {
            store.putEntity(local.copy(knownVersion = change.version))
        }
        if (conflict != null && change.version > conflict.server.version) {
            store.putConflict(conflict.copy(server = ServerCopy(change.version, change.state, change.document)))
        }
    }

    /**
     * Applies [receipts] for the sent commands, matched by `command_id` (they come back in the batch's order). Each
     * removes its command, then: `applied` records the version and closes any conflict; `duplicate` acts as its
     * original; `conflict` keeps the local document, opens a conflict and drops later unsent commands for the
     * entity; `merged` moves every local use of the tag to the surviving one; `gone` removes the entity;
     * `rejected` restores the server's copy (or removes the entity) and returns a notice.
     */
    public fun applyReceipts(store: SyncStore, receipts: List<Receipt>): List<SyncNotice> =
        receipts.mapNotNull { receipt ->
            val command = store.outbox().firstOrNull { it.commandId == receipt.commandId } ?: return@mapNotNull null
            store.replaceOutbox(store.outbox().filterNot { it.commandId == command.commandId })
            apply(store, command, receipt.outcome)
        }

    private fun apply(store: SyncStore, command: OutboxCommand, outcome: Receipt): SyncNotice? {
        val key = command.key
        when (outcome) {
            is Receipt.Applied -> {
                store.entity(key)?.let { store.putEntity(it.copy(knownVersion = outcome.version)) }
                store.removeConflict(key)
                outcome.cascaded.orEmpty().forEach { applyCascaded(store, it) }
            }
            is Receipt.Conflict -> {
                val local = store.entity(key)
                local?.let { store.putEntity(it.copy(knownVersion = outcome.current.version)) }
                dropUnsent(store, key)
                val localOp = if (local != null) SyncOp.PUT else SyncOp.DELETE
                store.putConflict(SyncConflict(key, localOp, outcome.current))
            }
            is Receipt.Merged -> merge(store, key.id, outcome)
            is Receipt.Gone -> remove(store, key)
            is Receipt.Rejected -> {
                val current = outcome.current
                if (current != null && current.state == EntityState.ACTIVE && current.document != null) {
                    dropUnsent(store, key)
                    store.removeConflict(key)
                    store.putEntity(LocalEntity(key, current.version, current.document))
                } else {
                    remove(store, key)
                }
                return SyncNotice(outcome.code, key)
            }
            // Receipt.outcome never is a duplicate.
            is Receipt.Duplicate -> Unit
        }
        return null
    }

    /**
     * One entity a delete cascaded to on the server: an active one the phone has takes the version as its known
     * version, so its next edit doesn't conflict; a deleted one goes. Queued commands for it keep their
     * `base_version` and settle as normal. The document itself arrives in the changes feed.
     */
    private fun applyCascaded(store: SyncStore, cascaded: CascadedChange) {
        val local = store.entity(cascaded.key)
        when {
            cascaded.state == EntityState.DELETED -> if (local != null) remove(store, cascaded.key)
            local != null -> store.putEntity(local.copy(knownVersion = cascaded.version))
        }
    }

    /**
     * Resolves the open conflict on [key]. Keep mine queues the local document (or the delete) again on the
     * server's version with [commandId], following the queue rules; Use theirs takes the server's copy and drops
     * anything unsent for the entity. A server copy that is itself deleted can only be taken.
     */
    public fun resolve(store: SyncStore, key: EntityKey, choice: ConflictChoice, commandId: AwradId?) {
        val conflict = store.conflict(key) ?: return
        store.removeConflict(key)
        val server = conflict.server
        if (choice == ConflictChoice.KEEP_MINE && server.state == EntityState.ACTIVE) {
            val local = store.entity(key)
            local?.let { if (it.knownVersion < server.version) store.putEntity(it.copy(knownVersion = server.version)) }
            val edit = LocalEdit(
                commandId = checkNotNull(commandId) { "Keep mine needs a new command ID" },
                key = key,
                op = if (local != null) SyncOp.PUT else SyncOp.DELETE,
                document = local?.document,
            )
            store.replaceOutbox(Outbox.enqueue(store.outbox(), server.version, edit))
        } else {
            dropUnsent(store, key)
            val document = server.document
            if (server.state == EntityState.ACTIVE && document != null) {
                store.putEntity(LocalEntity(key, server.version, document))
            } else {
                remove(store, key)
            }
        }
    }

    /** Removes [key] with its unsent commands and conflict, cascading as the server does. */
    public fun remove(store: SyncStore, key: EntityKey) {
        store.removeEntity(key)
        dropUnsent(store, key)
        store.removeConflict(key)
        when (key.type) {
            EntityType.CUSTOM_DHIKR -> remove(store, personalKeyOf(key.id))
            EntityType.USER_TAG -> rewriteTag(store, key.id, replacement = null)
            EntityType.DHIKR_PERSONAL -> Unit
        }
    }

    private fun merge(store: SyncStore, oldId: AwradId, merged: Receipt.Merged) {
        val oldKey = EntityKey(EntityType.USER_TAG, oldId)
        store.removeEntity(oldKey)
        dropUnsent(store, oldKey)
        store.removeConflict(oldKey)
        val survivor = EntityKey(EntityType.USER_TAG, merged.mergedInto)
        val document = merged.current.document
        if (store.entity(survivor) == null && merged.current.state == EntityState.ACTIVE && document != null) {
            store.putEntity(LocalEntity(survivor, merged.current.version, document))
        }
        rewriteTag(store, oldId, replacement = merged.mergedInto)
    }

    /**
     * Replaces the tag [tagId] with [replacement] (or takes it out, when null) in every local `dhikr_personal`
     * document and unsent command, keeping first occurrences only.
     */
    private fun rewriteTag(store: SyncStore, tagId: AwradId, replacement: AwradId?) {
        store.entities(EntityType.DHIKR_PERSONAL).forEach { entity ->
            val tags = PersonalDocument.tagIds(entity.document)
            if (tagId in tags) {
                store.putEntity(entity.copy(document = PersonalDocument.of(tags.rewritten(tagId, replacement))))
            }
        }
        val outbox = store.outbox()
        val rewritten = Outbox.rewriteTag(outbox, tagId, replacement)
        if (rewritten != outbox) store.replaceOutbox(rewritten)
    }

    private fun dropUnsent(store: SyncStore, key: EntityKey) {
        val outbox = store.outbox()
        val kept = outbox.filterNot { it.key == key && !it.sent }
        if (kept.size != outbox.size) store.replaceOutbox(kept)
    }
}
