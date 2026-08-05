package app.awrad.awrad_dhikrgoalstracker.ui.screens.createdhikr

import app.awrad.awrad_dhikrgoalstracker.service.StagedOwnedAudio
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CreateDhikrAudioDraftPolicyTest {

    @Test
    fun removeAudioMarksPendingWithoutImmediateOwnedDeletion() {
        val next = CreateDhikrAudioDraftPolicy.onRemoveClicked(
            hasPersistedOwnedAudio = true,
            currentStaged = null,
        )
        assertTrue(next.removeOwnedAudioPending)
        assertNull(next.stagedAudio)
        assertFalse(next.shouldDeleteOwnedAudioImmediately)
        assertTrue(next.shouldDeleteOwnedAudioOnSave)
    }

    @Test
    fun cancelOrClearDoesNotDeletePersistedOwnedAudio() {
        val pending = CreateDhikrAudioDraftPolicy.onRemoveClicked(
            hasPersistedOwnedAudio = true,
            currentStaged = null,
        )
        assertFalse(CreateDhikrAudioDraftPolicy.shouldDeleteOwnedAudioOnCancel(pending))
    }

    @Test
    fun successfulReplacementDiscardsPreviousStagedOnlyAfterNewStage() {
        val previous = staged("old.tmp")
        val replacement = staged("new.tmp")
        val decision = CreateDhikrAudioDraftPolicy.onReplacementStaged(
            previousStaged = previous,
            newStaged = replacement,
        )
        assertEquals(replacement, decision.keepStaged)
        assertEquals(previous, decision.discardStaged)
        assertFalse(decision.removeOwnedAudioPending)
    }

    @Test
    fun failedReplacementKeepsPreviousStaged() {
        val previous = staged("keep.tmp")
        val decision = CreateDhikrAudioDraftPolicy.onReplacementFailed(previousStaged = previous)
        assertEquals(previous, decision.keepStaged)
        assertNull(decision.discardStaged)
    }

    private fun staged(name: String) = StagedOwnedAudio(
        tempFile = File(name),
        relativeFileName = name,
        mimeType = "audio/mpeg",
        byteSize = 4,
        durationMs = 100,
        sha256 = "abc",
    )
}
