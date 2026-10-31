package app.awrad.core.domain.sync

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.goal.GoalOrder
import app.awrad.core.domain.goal.GoalOrderJson
import app.awrad.core.domain.goal.rules.GoalOrderMerge

/**
 * Conflicts on goals and the goal order open no "Changed on another device" prompt (fixture `apply_changes`;
 * contracts/sync/v1/README.md, "Goal conflicts").
 */
internal object GoalConflicts {

    /**
     * A goal edit or delete that lost (decision 44: the first to reach the server wins): the phone takes the server's
     * document and version (a deleted goal comes back; one the server deleted goes) and drops the goal's unsent
     * commands. The notice `goal_edit_not_applied` offers to do it again, unless the local document already equalled
     * the server's.
     */
    fun takeTheirs(store: SyncStore, key: EntityKey, current: ServerCopy): SyncNotice? {
        val local = store.entity(key)
        val document = current.document?.takeIf { current.state == EntityState.ACTIVE }
        if (document != null) {
            store.removeConflict(key)
            store.replaceOutbox(store.outbox().filterNot { it.key == key && !it.sent })
            store.putEntity(LocalEntity(key, current.version, document))
        } else {
            ApplyChanges.remove(store, key)
        }
        return SyncNotice(RejectionCode.GOAL_EDIT_NOT_APPLIED, key).takeIf { local?.document != document }
    }

    /**
     * A conflict on the goal order (fixture `goal_order_merge`): the local order merges with the server's against
     * `base_document` (an empty order when the phone knows none); the server's copy becomes the base and the known
     * version; the entity's unsent commands go (the local document already holds them); and the result is queued on
     * the server's version unless the server already has it.
     */
    fun mergeOrder(store: SyncStore, local: LocalEntity, current: ServerCopy, newCommandId: () -> AwradId) {
        val key = local.key
        store.replaceOutbox(store.outbox().filterNot { it.key == key && !it.sent })
        store.removeConflict(key)
        val theirsDocument = current.document?.takeIf { current.state == EntityState.ACTIVE } ?: return
        val theirs = GoalOrderJson.decode(theirsDocument)
        val mine = GoalOrderJson.decode(local.document)
        val base = local.baseDocument?.let(GoalOrderJson::decode) ?: GoalOrder.EMPTY
        val merge = if (theirs != null && mine != null) GoalOrderMerge.merge(base, mine, theirs) else null
        if (merge == null) {
            // A server copy this phone can't read (or a local one it can't) is taken as it is.
            store.putEntity(LocalEntity(key, current.version, theirsDocument, theirsDocument))
        } else {
            val document = GoalOrderJson.encode(merge.order)
            store.putEntity(LocalEntity(key, current.version, document, theirsDocument))
            if (merge.requeue) Outbox.enqueue(store, LocalEdit(newCommandId(), key, SyncOp.PUT, document))
        }
    }
}
