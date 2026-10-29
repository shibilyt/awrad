package app.awrad.core.data.practice

import app.awrad.core.data.sync.RoomSyncStore
import app.awrad.core.database.PracticePolicyEntity
import app.awrad.core.database.SyncDao
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.practice.LocalPolicy
import app.awrad.core.domain.practice.PracticePolicyFirstSignIn
import app.awrad.core.domain.practice.PracticePolicyJson
import app.awrad.core.domain.practice.ServerPolicy
import app.awrad.core.domain.sync.EntityKey
import app.awrad.core.domain.sync.EntityType
import app.awrad.core.domain.sync.LocalEdit
import app.awrad.core.domain.sync.Outbox
import app.awrad.core.domain.sync.SyncOp

/**
 * The practice policy's first sign-in (fixture `practice_policy_first_sign_in`), in two steps, since only the
 * account's changes feed says whether it already has a policy:
 * 1. [start], when the sign-in makes a new account profile from the anonymous one (adopted, or replaced by a fresh
 *    one on Erase): the profile takes the anonymous policy, bound to the account, and waits ([seedPending]);
 * 2. [settle], after the profile's first complete pull: a policy that arrived in the feed has already replaced the
 *    local one (`ApplyChanges.applyPage`); otherwise a chosen local policy is queued as a create, and untouched
 *    defaults are never sent ([PracticePolicyFirstSignIn]).
 *
 * Signing in to an account that already has a profile here keeps that profile's own policy: neither step runs.
 */
internal object PolicySeed {

    /**
     * Step 1: the new account profile takes [anonymous]'s policy, waiting for the account's. Without one (the user
     * never changed a setting) there's nothing to seed: the profile keeps the defaults, and takes the account's
     * policy when the feed brings one.
     */
    fun start(dao: SyncDao, anonymous: PracticePolicyEntity?, accountId: AwradId) {
        if (anonymous == null) return
        dao.upsertPracticePolicy(
            PracticePolicyEntity(
                entityId = accountId.value,
                knownVersion = 0,
                document = anonymous.document,
                baseDocument = null,
                chosen = anonymous.chosen,
                seedPending = true,
            ),
        )
    }

    /** Step 2, inside the pull's profile transaction. True when it queued the create, which then needs sending. */
    @Suppress("ReturnCount") // Nothing to settle, nothing to queue, or the create.
    fun settle(dao: SyncDao, accountId: AwradId, now: () -> Long, newId: () -> AwradId): Boolean {
        val row = dao.practicePolicy()?.takeIf { it.seedPending } ?: return false
        val policy = row.policy()
        val account = ServerPolicy(policy, row.knownVersion).takeIf { row.knownVersion > 0 }
        val decision = PracticePolicyFirstSignIn.decide(LocalPolicy(policy, row.chosen), account)
        dao.upsertPracticePolicy(row.copy(entityId = accountId.value, seedPending = false))
        val queued = decision.queued ?: return false
        val store = RoomSyncStore(dao, now = now)
        val key = EntityKey(EntityType.PRACTICE_POLICY, accountId)
        Outbox.enqueue(store, LocalEdit(newId(), key, SyncOp.PUT, PracticePolicyJson.encode(queued)))
        return true
    }
}
