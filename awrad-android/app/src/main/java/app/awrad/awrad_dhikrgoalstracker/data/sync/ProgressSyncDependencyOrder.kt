package app.awrad.awrad_dhikrgoalstracker.data.sync

import com.google.gson.JsonParser
import java.util.UUID

/**
 * Transfer dependency ranks aligned with Phoenix ProgressSync.Transfer ordering:
 * custom_dhikr and user_tag share rank 0; assignments follow tags; goals follow assignments.
 */
object ProgressSyncDependencyOrder {
    fun order(kind: String): Int = when (kind) {
        "custom_dhikr", "user_tag" -> 0
        "dhikr_tag_assignment" -> 1
        "goal" -> 2
        "count_projection" -> 3
        "conflict" -> 4
        else -> 5
    }
}

/**
 * When the server coalesces a duplicate user_tag create to a canonical id, rewrite local
 * assignment rows and pending outbox payloads from the rejected local id to the canonical id.
 *
 * Same-dhikr overlaps must delete the losing assignment rather than upsert onto the unique
 * (tagId, dhikrId) index already held by the canonical row.
 */
object UserTagCoalesceRepoint {
    data class Assignment(
        val id: UUID,
        val tagId: UUID,
        val dhikrId: UUID,
    )

    data class Plan(
        val assignmentIdsToDelete: Set<UUID>,
        val assignmentsToRepoint: List<Assignment>,
    )

    fun plan(
        losingAssignments: List<Assignment>,
        existingCanonicalDhikrIds: Set<UUID>,
        fromTagId: UUID,
        toTagId: UUID,
    ): Plan {
        if (fromTagId == toTagId) {
            return Plan(assignmentIdsToDelete = emptySet(), assignmentsToRepoint = emptyList())
        }
        val toDelete = linkedSetOf<UUID>()
        val toRepoint = mutableListOf<Assignment>()
        for (assignment in losingAssignments) {
            if (assignment.tagId != fromTagId) continue
            if (assignment.dhikrId in existingCanonicalDhikrIds) {
                toDelete += assignment.id
            } else {
                toRepoint += assignment.copy(tagId = toTagId)
            }
        }
        return Plan(assignmentIdsToDelete = toDelete, assignmentsToRepoint = toRepoint)
    }

    fun rewriteAssignmentTagIds(
        assignments: List<Assignment>,
        fromTagId: UUID,
        toTagId: UUID,
    ): List<Assignment> {
        if (fromTagId == toTagId) return assignments
        val existingCanonicalDhikrIds = assignments
            .filter { it.tagId == toTagId }
            .map { it.dhikrId }
            .toSet()
        val coalescePlan = plan(
            losingAssignments = assignments.filter { it.tagId == fromTagId },
            existingCanonicalDhikrIds = existingCanonicalDhikrIds,
            fromTagId = fromTagId,
            toTagId = toTagId,
        )
        val keptCanonical = assignments.filter { it.tagId == toTagId }
        return keptCanonical + coalescePlan.assignmentsToRepoint
    }

    fun rewritePendingAssignmentPayload(
        payloadJson: String,
        fromTagId: String,
        toTagId: String,
    ): String {
        val root = JsonParser.parseString(payloadJson).asJsonObject
        val document = root.getAsJsonObject("proposed_document") ?: return payloadJson
        if (document.has("tag_id") && document.get("tag_id").asString == fromTagId) {
            document.addProperty("tag_id", toTagId)
        }
        return root.toString()
    }
}
