package app.awrad.core.domain.sync

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.personal.PersonalDocument

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
     * - deleting a custom dhikr also drops never-sent commands for its `dhikr_personal`;
     * - deleting a tag queues only the tag delete, and takes the tag out of every never-sent `dhikr_personal`
     *   command in place: the server removes it from the records itself (the receipt's `cascaded`).
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
        return when {
            edit.op != SyncOp.DELETE -> queued
            edit.key.type == EntityType.CUSTOM_DHIKR -> {
                val personal = personalKeyOf(edit.key.id)
                queued.filterNot { it.key == personal && !it.sent }
            }
            edit.key.type == EntityType.USER_TAG -> rewriteTag(queued, edit.key.id, replacement = null)
            else -> queued
        }
    }

    /**
     * [outbox] with the tag [tagId] replaced by [replacement] (or taken out, when null) in every never-sent
     * `dhikr_personal` command, in place and keeping first occurrences only. Sent commands are never rewritten.
     */
    public fun rewriteTag(outbox: List<OutboxCommand>, tagId: AwradId, replacement: AwradId?): List<OutboxCommand> =
        outbox.map { command ->
            val document = command.document
            if (command.sent || command.key.type != EntityType.DHIKR_PERSONAL || document == null) return@map command
            val tags = PersonalDocument.tagIds(document)
            if (tagId in tags) {
                command.copy(document = PersonalDocument.of(tags.rewritten(tagId, replacement)))
            } else {
                command
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

/** This tag list with [tagId] replaced by [replacement] (or removed), keeping first occurrences only. */
internal fun List<AwradId>.rewritten(tagId: AwradId, replacement: AwradId?): List<AwradId> =
    mapNotNull { if (it == tagId) replacement else it }.distinct()
