package app.awrad.awrad_dhikrgoalstracker.data.repository

import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId

/**
 * Explicit child cleanup for custom/remote dhikr deletion. Does not rely on FK CASCADE:
 * assignments, goals, and audio-asset rows are deleted before the parent dhikr row.
 * Outbox enqueue order stays assignments → goals → custom_dhikr; owned-file cleanup is
 * post-commit via [Plan.ownedAudioRelativeFileName].
 */
object CustomDhikrDeletionCascade {
    data class Plan(
        val assignmentIdsToDelete: List<AwradId>,
        val goalIdsToDelete: List<AwradId>,
        val ownedAudioRelativeFileName: String?,
        val dhikrIdToDelete: AwradId,
        val childTableDeletesBeforeParent: Boolean = true,
    ) {
        fun outboxEntityTypesInOrder(): List<String> =
            assignmentIdsToDelete.map { "dhikr_tag_assignment" } +
                goalIdsToDelete.map { "goal" } +
                listOf("custom_dhikr")
    }

    fun plan(
        dhikrId: AwradId,
        goalIds: List<AwradId>,
        assignmentIds: List<AwradId>,
        ownedAudioRelativeFileName: String?,
    ): Plan = Plan(
        assignmentIdsToDelete = assignmentIds,
        goalIdsToDelete = goalIds,
        ownedAudioRelativeFileName = ownedAudioRelativeFileName,
        dhikrIdToDelete = dhikrId,
    )

    /** Ordered steps for local custom delete (outbox + DB children + parent + post-commit file). */
    fun localExecutionSteps(plan: Plan): List<String> = buildList {
        plan.assignmentIdsToDelete.forEach { _ -> add("outbox_dhikr_tag_assignment") }
        plan.goalIdsToDelete.forEach { _ -> add("outbox_goal") }
        add("outbox_custom_dhikr")
        add("delete_assignments")
        add("delete_goals")
        add("delete_audio_asset")
        add("delete_dhikr")
        if (plan.ownedAudioRelativeFileName != null) add("delete_owned_file_post_commit")
    }

    /** Ordered steps for remote delete (no outbox; explicit children + parent + post-commit file). */
    fun remoteExecutionSteps(plan: Plan): List<String> = buildList {
        add("delete_assignments")
        add("delete_goals")
        add("delete_audio_asset")
        add("delete_dhikr")
        if (plan.ownedAudioRelativeFileName != null) add("delete_owned_file_post_commit")
    }
}
