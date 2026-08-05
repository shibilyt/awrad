package app.awrad.awrad_dhikrgoalstracker.ui.screens.createdhikr

import app.awrad.awrad_dhikrgoalstracker.service.StagedOwnedAudio

/**
 * Draft-only audio edits for create/edit dhikr. Remove Audio is pending until Save;
 * Cancel / onCleared must not delete the persisted owned file. Replacement staging keeps
 * the previous staged file until the new stage succeeds.
 */
object CreateDhikrAudioDraftPolicy {
    data class RemoveDraftResult(
        val removeOwnedAudioPending: Boolean,
        val stagedAudio: StagedOwnedAudio?,
        val shouldDeleteOwnedAudioImmediately: Boolean,
        val shouldDeleteOwnedAudioOnSave: Boolean,
    )

    data class StageDecision(
        val keepStaged: StagedOwnedAudio?,
        val discardStaged: StagedOwnedAudio?,
        val removeOwnedAudioPending: Boolean = false,
    )

    fun onRemoveClicked(
        hasPersistedOwnedAudio: Boolean,
        currentStaged: StagedOwnedAudio?,
    ): RemoveDraftResult = RemoveDraftResult(
        // currentStaged is cleared by the caller; policy only decides pending delete.
        removeOwnedAudioPending = hasPersistedOwnedAudio,
        stagedAudio = null,
        shouldDeleteOwnedAudioImmediately = false,
        shouldDeleteOwnedAudioOnSave = hasPersistedOwnedAudio,
    ).also {
        // Keep signature intentional: callers pass the staged draft they will discard.
        check(currentStaged == null || it.stagedAudio == null)
    }

    fun shouldDeleteOwnedAudioOnCancel(draft: RemoveDraftResult): Boolean = false

    fun onReplacementStaged(
        previousStaged: StagedOwnedAudio?,
        newStaged: StagedOwnedAudio,
    ): StageDecision = StageDecision(
        keepStaged = newStaged,
        discardStaged = previousStaged,
        removeOwnedAudioPending = false,
    )

    fun onReplacementFailed(previousStaged: StagedOwnedAudio?): StageDecision = StageDecision(
        keepStaged = previousStaged,
        discardStaged = null,
    )
}
