package app.awrad.awrad_dhikrgoalstracker.data.sync

import com.google.gson.JsonObject
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.SyncStateEntity
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ProgressSyncRecoveryPolicyTest {
    @Test
    fun initialImportSubtractsAlreadyQueuedForegroundProgress() {
        assertEquals(4L, ProgressSyncImportMath.legacyAmount(5L, 1L))
        assertEquals(6L, ProgressSyncImportMath.legacyAmount(5L, -1L))
        assertEquals(0L, ProgressSyncImportMath.legacyAmount(1L, 2L))
    }

    @Test
    fun conflictDeltaDefaultsToUnresolvedAndRecognizesResolution() {
        assertFalse(ProgressSyncConflictDelta.isResolved(JsonObject()))
        assertFalse(
            ProgressSyncConflictDelta.isResolved(
                JsonObject().apply { addProperty("resolved", false) },
            ),
        )
        assertTrue(
            ProgressSyncConflictDelta.isResolved(
                JsonObject().apply { addProperty("resolved", true) },
            ),
        )
    }

    @Test
    fun snapshotConflictWithoutOriginOutboxRemainsVisibleAndDeduplicated() {
        val server = ProgressSyncConflict("command", "goal", "goal-id", "conflict")
        val duplicateLocal = server.copy(reason = "local")
        val countConflict = ProgressSyncConflict("count-command", null, null, "stale_basis")

        assertEquals(
            listOf(server, countConflict),
            ProgressSyncConflictMerge.merge(listOf(server), listOf(duplicateLocal, countConflict)),
        )
    }

    @Test
    fun tentativeBindingCanOnlyMoveBeforeAnyDurableSyncFootprint() {
        val tentative = SyncStateEntity(
            boundUserId = "old-user",
            actorId = "actor",
            installationId = "installation",
            initialImportPayloadJson = "{captured}",
            syncRequested = true,
        )
        val empty = SyncBindingFootprint(0, 0, 0, 0, 0, 0)

        assertTrue(ProgressSyncBindingPolicy.canRebindTentative(tentative, empty))
        assertFalse(
            ProgressSyncBindingPolicy.canRebindTentative(
                tentative.copy(initialImportCompleted = true),
                empty,
            ),
        )
        assertFalse(
            ProgressSyncBindingPolicy.canRebindTentative(
                tentative.copy(cursor = "cloud-cursor"),
                empty,
            ),
        )
        assertFalse(
            ProgressSyncBindingPolicy.canRebindTentative(
                tentative,
                empty.copy(outboxCount = 1),
            ),
        )
        assertFalse(
            ProgressSyncBindingPolicy.canRebindTentative(
                tentative.copy(pendingTransferId = "transfer"),
                empty,
            ),
        )
    }

    @Test
    fun commandResponseRequiresExactlyOneReceiptForEveryClaimedCommand() {
        assertTrue(ProgressSyncReceiptIntegrity.isComplete(listOf("a", "b"), listOf("b", "a")))
        assertFalse(ProgressSyncReceiptIntegrity.isComplete(listOf("a", "b"), listOf("a")))
        assertFalse(ProgressSyncReceiptIntegrity.isComplete(listOf("a", "b"), listOf("a", "a")))
        assertFalse(ProgressSyncReceiptIntegrity.isComplete(listOf("a"), listOf("a", "unknown")))
    }

    @Test
    fun purgedReceiptRecognizesEveryCanonicalFenceRepresentation() {
        assertTrue(
            ProgressSyncPurgeEffect.isFence(
                JsonObject().apply { addProperty("kind", "deletion_fence") },
            ),
        )
        assertTrue(
            ProgressSyncPurgeEffect.isFence(
                JsonObject().apply { addProperty("state", "purged") },
            ),
        )
        assertTrue(
            ProgressSyncPurgeEffect.isFence(
                JsonObject().apply { addProperty("purged", true) },
            ),
        )
        assertFalse(ProgressSyncPurgeEffect.isFence(JsonObject()))
    }
}
