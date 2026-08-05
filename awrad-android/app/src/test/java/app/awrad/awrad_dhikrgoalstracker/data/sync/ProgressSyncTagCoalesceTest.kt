package app.awrad.awrad_dhikrgoalstracker.data.sync

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ProgressSyncTagDependencyOrderTest {

    @Test
    fun dependencyOrderMatchesServerTransferOrdering() {
        // Server: custom_dhikr=0, user_tag=0, dhikr_tag_assignment=1, goal=2, count=3, conflict=4
        assertEquals(0, ProgressSyncDependencyOrder.order("custom_dhikr"))
        assertEquals(0, ProgressSyncDependencyOrder.order("user_tag"))
        assertEquals(1, ProgressSyncDependencyOrder.order("dhikr_tag_assignment"))
        assertEquals(2, ProgressSyncDependencyOrder.order("goal"))
        assertEquals(3, ProgressSyncDependencyOrder.order("count_projection"))
        assertEquals(4, ProgressSyncDependencyOrder.order("conflict"))
        assertTrue(
            ProgressSyncDependencyOrder.order("dhikr_tag_assignment") >
                ProgressSyncDependencyOrder.order("user_tag"),
        )
    }
}

class UserTagCoalesceRepointTest {

    @Test
    fun rewritesAssignmentsFromLocalTagToCanonicalTag() {
        val local = java.util.UUID.randomUUID()
        val canonical = java.util.UUID.randomUUID()
        val dhikr = java.util.UUID.randomUUID()
        val rewritten = UserTagCoalesceRepoint.rewriteAssignmentTagIds(
            assignments = listOf(
                UserTagCoalesceRepoint.Assignment(id = java.util.UUID.randomUUID(), tagId = local, dhikrId = dhikr),
                UserTagCoalesceRepoint.Assignment(id = java.util.UUID.randomUUID(), tagId = canonical, dhikrId = dhikr),
            ),
            fromTagId = local,
            toTagId = canonical,
        )
        assertEquals(setOf(canonical), rewritten.map { it.tagId }.toSet())
        assertEquals(1, rewritten.count { it.tagId == canonical && it.dhikrId == dhikr })
    }

    @Test
    fun pendingOutboxPayloadsRepointTagIdField() {
        val local = "11111111-1111-4111-8111-111111111111"
        val canonical = "22222222-2222-4222-8222-222222222222"
        val payload = """
            {"type":"entity_upsert","entity_type":"dhikr_tag_assignment","entity_id":"a",
             "proposed_document":{"id":"a","tag_id":"$local","dhikr_id":"d","created_at":"2026-01-01T00:00:00Z"}}
        """.trimIndent()
        val updated = UserTagCoalesceRepoint.rewritePendingAssignmentPayload(payload, local, canonical)
        assertTrue(updated.contains("\"tag_id\":\"$canonical\""))
        assertTrue(!updated.contains("\"tag_id\":\"$local\""))
    }

    @Test
    fun pushReceiptCoalesceDropsLosingAssignmentWhenCanonicalAlreadyOwnsDhikr() {
        val local = java.util.UUID.randomUUID()
        val canonical = java.util.UUID.randomUUID()
        val sharedDhikr = java.util.UUID.randomUUID()
        val onlyLocalDhikr = java.util.UUID.randomUUID()
        val losingShared = UserTagCoalesceRepoint.Assignment(
            id = java.util.UUID.randomUUID(),
            tagId = local,
            dhikrId = sharedDhikr,
        )
        val losingUnique = UserTagCoalesceRepoint.Assignment(
            id = java.util.UUID.randomUUID(),
            tagId = local,
            dhikrId = onlyLocalDhikr,
        )
        val plan = UserTagCoalesceRepoint.plan(
            losingAssignments = listOf(losingShared, losingUnique),
            existingCanonicalDhikrIds = setOf(sharedDhikr),
            fromTagId = local,
            toTagId = canonical,
        )
        assertEquals(setOf(losingShared.id), plan.assignmentIdsToDelete)
        assertEquals(listOf(losingUnique.copy(tagId = canonical)), plan.assignmentsToRepoint)
        assertTrue(plan.assignmentsToRepoint.none { it.dhikrId == sharedDhikr })
    }

    @Test
    fun bootstrapApplyRemoteCoalesceRepointsLosingLocalBeforeRemovingDuplicate() {
        val local = java.util.UUID.randomUUID()
        val canonical = java.util.UUID.randomUUID()
        val dhikr = java.util.UUID.randomUUID()
        val plan = UserTagCoalesceRepoint.plan(
            losingAssignments = listOf(
                UserTagCoalesceRepoint.Assignment(
                    id = java.util.UUID.randomUUID(),
                    tagId = local,
                    dhikrId = dhikr,
                ),
            ),
            existingCanonicalDhikrIds = emptySet(),
            fromTagId = local,
            toTagId = canonical,
        )
        assertTrue(plan.assignmentIdsToDelete.isEmpty())
        assertEquals(1, plan.assignmentsToRepoint.size)
        assertEquals(canonical, plan.assignmentsToRepoint.single().tagId)
        assertEquals(dhikr, plan.assignmentsToRepoint.single().dhikrId)
    }
}
