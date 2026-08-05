package app.awrad.awrad_dhikrgoalstracker.data.repository

import app.awrad.awrad_dhikrgoalstracker.data.model.newAwradId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CustomDhikrDeletionCascadeTest {

    @Test
    fun localAndRemotePlansExplicitlyListChildrenBeforeParent() {
        val dhikrId = newAwradId()
        val goalA = newAwradId()
        val goalB = newAwradId()
        val assignmentA = newAwradId()
        val assignmentB = newAwradId()

        val plan = CustomDhikrDeletionCascade.plan(
            dhikrId = dhikrId,
            goalIds = listOf(goalA, goalB),
            assignmentIds = listOf(assignmentA, assignmentB),
            ownedAudioRelativeFileName = "owned.mp3",
        )

        assertEquals(listOf(assignmentA, assignmentB), plan.assignmentIdsToDelete)
        assertEquals(listOf(goalA, goalB), plan.goalIdsToDelete)
        assertEquals("owned.mp3", plan.ownedAudioRelativeFileName)
        assertEquals(dhikrId, plan.dhikrIdToDelete)
        assertEquals(
            listOf("dhikr_tag_assignment", "dhikr_tag_assignment", "goal", "goal", "custom_dhikr"),
            plan.outboxEntityTypesInOrder(),
        )
        assertTrue(plan.childTableDeletesBeforeParent)
    }

    @Test
    fun localPathKeepsOutboxOrderThenExplicitChildrenThenPostCommitFile() {
        val plan = CustomDhikrDeletionCascade.plan(
            dhikrId = newAwradId(),
            goalIds = listOf(newAwradId()),
            assignmentIds = listOf(newAwradId()),
            ownedAudioRelativeFileName = "local.mp3",
        )
        val steps = CustomDhikrDeletionCascade.localExecutionSteps(plan)
        assertEquals(
            listOf(
                "outbox_dhikr_tag_assignment",
                "outbox_goal",
                "outbox_custom_dhikr",
                "delete_assignments",
                "delete_goals",
                "delete_audio_asset",
                "delete_dhikr",
                "delete_owned_file_post_commit",
            ),
            steps,
        )
        val parentIndex = steps.indexOf("delete_dhikr")
        assertTrue(steps.indexOf("delete_assignments") < parentIndex)
        assertTrue(steps.indexOf("delete_goals") < parentIndex)
        assertTrue(steps.indexOf("delete_audio_asset") < parentIndex)
        assertTrue(steps.indexOf("delete_owned_file_post_commit") > parentIndex)
    }

    @Test
    fun remotePathSkipsOutboxButDeletesChildrenBeforeParentAndFileAfterCommit() {
        val plan = CustomDhikrDeletionCascade.plan(
            dhikrId = newAwradId(),
            goalIds = listOf(newAwradId()),
            assignmentIds = listOf(newAwradId(), newAwradId()),
            ownedAudioRelativeFileName = "remote-only.m4a",
        )
        val steps = CustomDhikrDeletionCascade.remoteExecutionSteps(plan)
        assertFalse(steps.any { it.startsWith("outbox_") })
        assertEquals(
            listOf(
                "delete_assignments",
                "delete_goals",
                "delete_audio_asset",
                "delete_dhikr",
                "delete_owned_file_post_commit",
            ),
            steps,
        )
        assertEquals("remote-only.m4a", plan.ownedAudioRelativeFileName)
    }
}
