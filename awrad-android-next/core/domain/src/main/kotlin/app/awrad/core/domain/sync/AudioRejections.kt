package app.awrad.core.domain.sync

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.personal.CustomAudioJson
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject

/**
 * A custom dhikr put rejected with `audio_not_found` or `audio_mismatch` loses nothing (fixture `apply_changes`;
 * contracts/sync/v1/README.md, "Audio rejections lose nothing"). Its asset was cleaned up, or never confirmed,
 * while the put waited; the user's edit itself is fine.
 */
internal object AudioRejections {

    private val CODES = setOf(RejectionCode.AUDIO_NOT_FOUND, RejectionCode.AUDIO_MISMATCH)

    /** Whether [rejected] is an audio rejection of a custom dhikr put. */
    fun applies(command: OutboxCommand, rejected: Receipt.Rejected): Boolean =
        rejected.code in CODES && command.key.type == EntityType.CUSTOM_DHIKR && command.op == SyncOp.PUT

    /**
     * Keeps the local document of [key] with its `audio` fixed: `{"local_only": true}` with the upload queued again
     * when the recording's file is still on the phone, else null. The known version becomes the server's ([current]'s,
     * or 0 when it has none), and the entity's unsent commands become one put of the kept document on that version,
     * ahead of every other unsent command. If the dhikr was deleted here since, that's a delete on the server's
     * version instead, or nothing when the server has no copy.
     */
    fun keepEdit(store: SyncStore, key: EntityKey, current: ServerCopy?, newCommandId: () -> AwradId) {
        val version = current?.version ?: 0L
        val local = store.entity(key)
        store.removeConflict(key)
        val command = if (local != null) {
            val hasFile = store.hasAudioFile(key.id)
            val audio = if (hasFile) CustomAudioJson.LOCAL_ONLY else JsonNull
            val document = JsonObject(local.document + ("audio" to audio))
            store.putEntity(LocalEntity(key, version, document))
            if (hasFile) store.queueUpload(key.id)
            OutboxCommand(newCommandId(), key, SyncOp.PUT, version, document, sent = false)
        } else if (current != null && current.state == EntityState.ACTIVE) {
            OutboxCommand(newCommandId(), key, SyncOp.DELETE, version, document = null, sent = false)
        } else {
            null
        }
        val others = store.outbox().filterNot { it.key == key && !it.sent }
        val queued = if (command == null) {
            others
        } else {
            val at = others.indexOfFirst { !it.sent }.takeIf { it >= 0 } ?: others.size
            others.take(at) + command + others.drop(at)
        }
        if (queued != store.outbox()) store.replaceOutbox(queued)
    }
}
