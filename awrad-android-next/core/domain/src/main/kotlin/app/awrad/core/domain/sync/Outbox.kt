package app.awrad.core.domain.sync

/**
 * How a phone queues one saved edit (fixture `outbox_enqueue`; contracts/sync/v1/README.md, "Saving an edit").
 * The edit and its queue change are one local transaction ([enqueue] on a [SyncStore]).
 */
public object Outbox {

    /**
     * The queue after [edit], given the queue [outbox] (oldest first) and the version this phone knows of the
     * edited entity ([knownVersion], 0 when the server has never had it):
     * - if the entity's last queued command was never sent, the edit replaces it in place, keeping its
     *   `command_id`, `base_version` and position; but a delete replacing a never-sent create (`base_version` 0)
     *   removes it, since the server never heard of the entity;
     * - otherwise a new command goes at the end, on the last queued command's `base_version` + 1, or on
     *   [knownVersion] when nothing is queued for the entity;
     * - deleting a custom dhikr also drops never-sent commands for its `dhikr_personal`.
     */
    public fun enqueue(outbox: List<OutboxCommand>, knownVersion: Long, edit: LocalEdit): List<OutboxCommand> {
        val lastIndex = outbox.indexOfLast { it.key == edit.key }
        val last = outbox.getOrNull(lastIndex)
        val queued = when {
            last != null && !last.sent && edit.op == SyncOp.DELETE && last.baseVersion == 0L ->
                outbox.filterIndexed { index, _ -> index != lastIndex }
            last != null && !last.sent ->
                outbox.toMutableList().also { it[lastIndex] = last.copy(op = edit.op, document = edit.document) }
            else -> outbox + OutboxCommand(
                commandId = edit.commandId,
                key = edit.key,
                op = edit.op,
                baseVersion = last?.baseVersion?.plus(1) ?: knownVersion,
                document = edit.document,
                sent = false,
            )
        }
        return if (edit.key.type == EntityType.CUSTOM_DHIKR && edit.op == SyncOp.DELETE) {
            val personal = personalKeyOf(edit.key.id)
            queued.filterNot { it.key == personal && !it.sent }
        } else {
            queued
        }
    }

    /** Queues [edit] in [store]: [enqueue] with the entity's known version (0 when it isn't on the phone). */
    public fun enqueue(store: SyncStore, edit: LocalEdit) {
        val known = store.entity(edit.key)?.knownVersion ?: 0L
        store.replaceOutbox(enqueue(store.outbox(), known, edit))
    }

    /** Commands that haven't been acknowledged yet: what Settings counts as "not synced". */
    public fun pendingCount(outbox: List<OutboxCommand>): Int = outbox.size
}
